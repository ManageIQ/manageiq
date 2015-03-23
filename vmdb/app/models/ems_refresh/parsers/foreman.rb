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
        # pull out ids because operating system flavors cross link to the customization scripts
        medium_ids = add_ids({}, media)
        ptable_ids = add_ids({}, ptables)

        result[:customization_scripts] = media + ptables
        result[:operating_system_flavors] = operating_system_flavors_inv_to_hashes(inv[:operating_systems],
                                                                                   medium_ids,
                                                                                   ptable_ids)
        result[:configuration_locations] = location_inv_to_hashes(inv[:locations])
        result[:configuration_organizations] = organization_inv_to_hashes(inv[:organizations])
        result
      end

      # data coming in from foreman:
      #   :hostgroups
      #   :hosts
      # data coming in from database (already in the form of ids)
      #   :media
      #   :ptables
      #   :operating_systems
      #   :locations
      #   :organizations
      def configuration_inv_to_hashes(inv)
        result = {}
        ids = {}
        result[:configuration_profiles] = configuration_profile_inv_to_hashes(inv[:hostgroups],
                                                                              inv[:operating_system_flavors],
                                                                              inv[:media],
                                                                              inv[:ptables],
                                                                              inv[:locations],
                                                                              inv[:organizations])
        add_ids(ids, result[:configuration_profiles])
        result[:configured_systems] = configured_system_inv_to_hashes(inv[:hosts],
                                                                      ids,
                                                                      inv[:operating_system_flavors],
                                                                      inv[:locations],
                                                                      inv[:organizations])
        result[:needs_provisioning_refresh] = true if needs_provisioning_refresh
        result
      end

      def media_inv_to_hashes(media)
        media.collect do |m|
          {
            :manager_ref => m["id"].to_s,
            :type        => "CustomizationScriptMedium",
            :name        => m["name"]
          }
        end
      end

      def ptables_inv_to_hashes(ptables)
        ptables.collect do |m|
          {
            :manager_ref => m["id"].to_s,
            :type        => "CustomizationScriptPtable",
            :name        => m["name"]
          }
        end
      end

      def location_inv_to_hashes(locations)
        locations.collect do |m|
          {
            :manager_ref => m["id"].to_s,
            :type        => "ConfigurationLocation",
            :name        => m["name"],
          }
        end
      end

      def organization_inv_to_hashes(organizations)
        organizations.collect do |m|
          {
            :manager_ref => m["id"].to_s,
            :type        => "ConfigurationOrganization",
            :name        => m["name"],
          }
        end
      end

      def operating_system_flavors_inv_to_hashes(flavors_inv, medium_ids, ptable_ids)
        flavors_inv.collect do |os|
          {
            :manager_ref           => os["id"].to_s,
            :name                  => os["fullname"],
            :description           => os["description"],
            :customization_scripts => ids_lookup(medium_ids, os["media"]) + ids_lookup(ptable_ids, os["ptables"])
          }
        end
      end

      def configuration_profile_inv_to_hashes(recs, osfs, media, ptables, locations, organizations)
        recs.collect do |profile|
          {
            :type                           => "ConfigurationProfileForeman",
            :manager_ref                    => profile["id"].to_s,
            :name                           => profile["name"],
            :description                    => profile["title"],
            :operating_system_flavor_id     => id_lookup(osfs, profile, "operatingsystem_id"),
            :customization_script_medium_id => id_lookup(media, profile, "medium_id"),
            :customization_script_ptable_id => id_lookup(ptables, profile, "ptable_id"),
            :configuration_location_ids     => ids_lookup(locations, profile["locations"]),
            :configuration_organization_ids => ids_lookup(organizations, profile["organizations"]),
          }
        end
      end

      def configured_system_inv_to_hashes(recs, profiles, operatingsystems, locations, organizations)
        recs.collect do |cs|
          {
            :type                          => "ConfiguredSystemForeman",
            :manager_ref                   => cs["id"].to_s,
            :hostname                      => cs["name"],
            :configuration_profile         => id_lookup(profiles, cs, "hostgroup_id"),
            :operating_system_flavor_id    => id_lookup(operatingsystems, cs, "operatingsystem_id"),
            :last_checkin                  => cs["last_compile"],
            :build_state                   => cs["build"] ? "pending" : nil,
            :configuration_location_id     => id_lookup(locations, cs, "location_id"),
            :configuration_organization_id => id_lookup(organizations, cs, "organization_id"),
          }
        end
      end

      private

      def add_ids(target, recs, key = :manager_ref)
        recs.each { |r| target[r[key]] = r }
        target
      end

      def id_lookup(ids, record, id_key)
        key = record[id_key]
        return unless key
        ids[key.to_s].tap do |v|
          @needs_provisioning_refresh = true unless v
        end
      end

      def ids_lookup(ids, records, id_key = "id")
        (records || []).collect { |record| id_lookup(ids, record, id_key) }.compact
      end
    end
  end
end
