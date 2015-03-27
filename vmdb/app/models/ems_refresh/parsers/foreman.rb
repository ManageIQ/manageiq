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
        media = media_inv_to_hashes(inv[:media])
        ptables = ptables_inv_to_hashes(inv[:ptables])
        # pull out ids for operating system flavors cross link to the customization scripts
        indexes = {
          :media   => add_ids(media),
          :ptables => add_ids(ptables),
        }

        {
          :customization_scripts       => media + ptables,
          :operating_system_flavors    => operating_system_flavors_inv_to_hashes(inv[:operating_systems], indexes),
          :configuration_locations     => location_inv_to_hashes(inv[:locations]),
          :configuration_organizations => organization_inv_to_hashes(inv[:organizations]),
        }
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

        {
          :configuration_profiles     => configuration_profile_inv_to_hashes(inv[:hostgroups], indexes),
          :configured_systems         => configured_system_inv_to_hashes(inv[:hosts], indexes),
          :needs_provisioning_refresh => needs_provisioning_refresh,
        }
      end

      def media_inv_to_hashes(media)
        basic_hash(media, "CustomizationScriptMedium")
      end

      def ptables_inv_to_hashes(ptables)
        basic_hash(ptables, "CustomizationScriptPtable")
      end

      def location_inv_to_hashes(locations)
        basic_hash(locations || tax_refs, "ConfigurationLocation", "title")
      end

      def organization_inv_to_hashes(organizations)
        basic_hash(organizations || tax_refs, "ConfigurationOrganization", "title")
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
            :configuration_location_ids     => ids_lookup(indexes[:locations], profile["locations"] || tax_refs),
            :configuration_organization_ids => ids_lookup(indexes[:organizations], profile["organizations"] || tax_refs),
          }
        end.tap do |profiles|
          indexes[:profiles] = add_ids(profiles)
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
            :configuration_location_id      => id_lookup(indexes[:locations], cs["location_id"] || 0),
            :configuration_organization_id  => id_lookup(indexes[:organizations], cs["organization_id"] || 0),
          }
        end
      end

      private

      def add_ids(recs, key = :manager_ref)
        recs.each_with_object({}) { |r, target| target[r[key]] = r }
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

      # default taxonomy reference (locations and organizations)
      def tax_refs
        [{"id" => 0, "name" => "Default", "title" => "Default"}]
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
