module EmsRefresh
  module Parsers
    class Foreman
      # we referenced a record that does not exist in the database
      attr_accessor :needs_provisioning_refresh

      def self.provisioning_inv_to_hashes(inv)
        new.provisioning_inv_to_hashes(inv)
      end

      def self.configuration_inv_to_hashes(inv)
        new.configuration_inv_to_hashes(inv)
      end

      # data coming in from foreman:
      #   :media
      #   :ptables
      #   :operating_systems
      #   :locations
      #   :organizations
      def provisioning_inv_to_hashes(inv)
        result = {}
        media = media_inv_to_hashes(inv[:media])
        ptables = ptables_inv_to_hashes(inv[:ptables])
        # pull out ids for operating system flavors cross link to the customization scripts
        indexes = {
          :media   => add_ids({}, media),
          :ptables => add_ids({}, ptables),
        }

        result[:customization_scripts] = media + ptables
        result[:operating_system_flavors] = operating_system_flavors_inv_to_hashes(inv[:operating_systems], indexes)
        result[:configuration_locations] = location_inv_to_hashes(inv[:locations])
        result[:configuration_organizations] = organization_inv_to_hashes(inv[:organizations])
        result
      end

      # data coming in from foreman:
      #   :hostgroups
      #   :hosts
      # data coming in from database (already in the form of ids)
      #   see indexes variable
      def configuration_inv_to_hashes(inv)
        indexes = {
          :flavors       => inv[:operating_system_flavors],
          :media         => inv[:media],
          :ptables       => inv[:ptables],
          :locations     => inv[:locations],
          :organizations => inv[:organizations],
        }
        result = {}
        result[:configuration_profiles] = configuration_profile_inv_to_hashes(inv[:hostgroups], indexes)
        indexes[:profiles] = add_ids({}, result[:configuration_profiles])
        result[:configured_systems] = configured_system_inv_to_hashes(inv[:hosts], indexes)
        result[:needs_provisioning_refresh] = true if needs_provisioning_refresh
        result
      end

      def media_inv_to_hashes(media)
        basic_hash(media, "CustomizationScriptMedium")
      end

      def ptables_inv_to_hashes(ptables)
        basic_hash(ptables, "CustomizationScriptPtable")
      end

      def location_inv_to_hashes(locations)
        basic_hash(locations, "ConfigurationLocation", "title")
      end

      def organization_inv_to_hashes(organizations)
        basic_hash(organizations, "ConfigurationOrganization", "title")
      end

      def operating_system_flavors_inv_to_hashes(flavors_inv, indexes)
        flavors_inv.collect do |os|
          {
            :manager_ref           => os["id"].to_s,
            :name                  => os["fullname"],
            :description           => os["description"],
            :customization_scripts => ids_lookup(indexes[:media], os["media"]) +
                                      ids_lookup(indexes[:ptables], os["ptables"])
          }
        end
      end

      def configuration_profile_inv_to_hashes(recs, indexes)
        recs.collect do |profile|
          {
            :type                           => "ConfigurationProfileForeman",
            :manager_ref                    => profile["id"].to_s,
            :name                           => profile["name"],
            :description                    => profile["title"],
            :operating_system_flavor_id     => id_lookup(indexes[:flavors], profile["operatingsystem_id"]),
            :customization_script_medium_id => id_lookup(indexes[:media], profile["medium_id"]),
            :customization_script_ptable_id => id_lookup(indexes[:ptables], profile["ptable_id"]),
            :configuration_location_ids     => ids_lookup(indexes[:locations], profile["locations"]),
            :configuration_organization_ids => ids_lookup(indexes[:organizations], profile["organizations"]),
          }
        end
      end

      def configured_system_inv_to_hashes(recs, indexes)
        recs.collect do |cs|
          {
            :type                           => "ConfiguredSystemForeman",
            :manager_ref                    => cs["id"].to_s,
            :hostname                       => cs["name"],
            :configuration_profile          => id_lookup(indexes[:profiles], cs["hostgroup_id"]),
            :operating_system_flavor_id     => id_lookup(indexes[:flavors], cs["operatingsystem_id"]),
            :customization_script_medium_id => id_lookup(indexes[:media], cs["medium_id"]),
            :customization_script_ptable_id => id_lookup(indexes[:ptables], cs["ptable_id"]),
            :last_checkin                   => cs["last_compile"],
            :build_state                    => cs["build"] ? "pending" : nil,
            :ipaddress                      => cs["ip"],
            :mac_address                    => cs["mac"],
            :configuration_location_id      => id_lookup(indexes[:locations], cs["location_id"]),
            :configuration_organization_id  => id_lookup(indexes[:organizations], cs["organization_id"]),
          }
        end
      end

      private

      def add_ids(target, recs, key = :manager_ref)
        recs.each { |r| target[r[key]] = r }
        target
      end

      def id_lookup(ids, key)
        return unless key
        ids[key.to_s].tap do |v|
          @needs_provisioning_refresh = true unless v
        end
      end

      def ids_lookup(ids, records, id_key = "id")
        (records || []).collect { |record| id_lookup(ids, record[id_key]) }.compact
      end

      def basic_hash(collection, type, extra_field = nil)
        collection.collect do |m|
          {
            :manager_ref => m["id"].to_s,
            :type        => type,
            :name        => m["name"],
          }.tap do |h|
            h[extra_field] = m[extra_field] if extra_field
          end
        end
      end
    end
  end
end
