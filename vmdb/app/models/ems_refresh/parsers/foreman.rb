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
        media            = media_inv_to_hashes(inv[:media])
        ptables          = ptables_inv_to_hashes(inv[:ptables])

        indexes = {
          :media            => add_ids(media),
          :ptables          => add_ids(ptables),
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
        architectures    = architectures_inv_to_hashes(inv[:architectures])
        compute_profiles = compute_profiles_inv_to_hashes(inv[:compute_profiles])
        domains          = domains_inv_to_hashes(inv[:domains])
        environments     = environments_inv_to_hashes(inv[:environments])
        realms           = realms_inv_to_hashes(inv[:realms])

        indexes = {
          :flavors          => inv[:operating_system_flavors],
          :media            => inv[:media],
          :ptables          => inv[:ptables],
          :locations        => inv[:locations],
          :organizations    => inv[:organizations],
          :architectures    => add_ids(architectures),
          :compute_profiles => add_ids(compute_profiles),
          :domains          => add_ids(domains),
          :environments     => add_ids(environments),
          :realms           => add_ids(realms),
        }

        {
          :configuration_profiles     => configuration_profile_inv_to_hashes(inv[:hostgroups], indexes),
          :configuration_tags         => architectures + compute_profiles + domains + environments + realms,
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
        backfill_parent_ref(basic_hash(locations || tax_refs, "ConfigurationLocation", "title"))
      end

      def organization_inv_to_hashes(organizations)
        backfill_parent_ref(basic_hash(organizations || tax_refs, "ConfigurationOrganization", "title"))
      end

      def architectures_inv_to_hashes(architectures)
        basic_hash(architectures, "ConfigurationArchitecture")
      end

      def compute_profiles_inv_to_hashes(compute_profiles)
        basic_hash(compute_profiles, "ConfigurationComputeProfile")
      end

      def domains_inv_to_hashes(domains)
        basic_hash(domains, "ConfigurationDomain")
      end

      def environments_inv_to_hashes(environments)
        basic_hash(environments, "ConfigurationEnvironment")
      end

      def realms_inv_to_hashes(realms)
        basic_hash(realms, "ConfigurationRealm")
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
        def_loc = tax_refs if indexes[:locations].keys == %w(0)
        def_org = tax_refs if indexes[:organizations].keys == %w(0)
        recs.collect do |profile|
          {
            :type                                  => "ConfigurationProfileForeman",
            :manager_ref                           => profile["id"].to_s,
            :parent_ref                            => (profile["ancestry"] || "").split("/").last.presence,
            :name                                  => profile["name"],
            :description                           => profile["title"],
            :direct_configuration_tag_ids          => [
              id_lookup(indexes[:architectures], profile["architecture_id"]),
              id_lookup(indexes[:compute_profiles], profile["compute_profile_id"]),
              id_lookup(indexes[:domains], profile["domain_id"]),
              id_lookup(indexes[:environments], profile["environment_id"]),
              id_lookup(indexes[:realms], profile["realm_id"]),
            ].compact,
            :direct_operating_system_flavor_id     => id_lookup(indexes[:flavors], profile["operatingsystem_id"]),
            :direct_customization_script_medium_id => id_lookup(indexes[:media], profile["medium_id"]),
            :direct_customization_script_ptable_id => id_lookup(indexes[:ptables], profile["ptable_id"]),
            :configuration_location_ids            => ids_lookup(indexes[:locations], profile["locations"] || def_loc),
            :configuration_organization_ids        => ids_lookup(indexes[:organizations], profile["organizations"] || def_org),
          }
        end.tap do |profiles|
          # populate profiles with rolled up values
          profiles.each do |p|
            # pull back a few fields that are to be merged
            ancestor_values = family_tree(profiles, p).map do |hash|
              {
                :operating_system_flavor_id     => hash[:direct_operating_system_flavor_id],
                :customization_script_medium_id => hash[:direct_customization_script_medium_id],
                :customization_script_ptable_id => hash[:direct_customization_script_ptable_id],
              }
            end
            rollup(p, ancestor_values)

            invalid = []
            invalid << "location" if p[:configuration_location_ids].empty?
            invalid << "organization" if p[:configuration_organization_ids].empty?
            $log.warn "Foreman hostgroup #{p[:name]} missing: #{invalid.join(", ")}" unless invalid.empty?
          end
          indexes[:profiles] = add_ids(profiles)
        end
      end

      def configured_system_inv_to_hashes(recs, indexes)
        def_loc = 0 if indexes[:locations].keys == %w(0)
        def_org = 0 if indexes[:organizations].keys == %w(0)
        recs.collect do |cs|
          {
            :type                                  => "ConfiguredSystemForeman",
            :manager_ref                           => cs["id"].to_s,
            :hostname                              => cs["name"],
            :configuration_profile                 => id_lookup(indexes[:profiles], cs["hostgroup_id"]),
            :direct_operating_system_flavor_id     => id_lookup(indexes[:flavors], cs["operatingsystem_id"]),
            :direct_customization_script_medium_id => id_lookup(indexes[:media], cs["medium_id"]),
            :direct_customization_script_ptable_id => id_lookup(indexes[:ptables], cs["ptable_id"]),
            :direct_configuration_tag_ids          => [
              id_lookup(indexes[:architectures], cs["architecture_id"]),
              id_lookup(indexes[:compute_profiles], cs["compute_profile_id"]),
              id_lookup(indexes[:domains], cs["domain_id"]),
              id_lookup(indexes[:environments], cs["environment_id"]),
              id_lookup(indexes[:realms], cs["realm_id"])].compact,
            :last_checkin                          => cs["last_compile"],
            :build_state                           => cs["build"] ? "pending" : nil,
            :ipaddress                             => cs["ip"],
            :mac_address                           => cs["mac"],
            :ipmi_present                          => cs["sp_ip"].present?,
            :configuration_location_id             => id_lookup(indexes[:locations], cs["location_id"] || def_loc),
            :configuration_organization_id         => id_lookup(indexes[:organizations], cs["organization_id"] || def_org),
          }
        end.tap do |systems|
          # if the system doesn't have a value, use the rolled up profile value
          systems.each do |s|
            parent = s[:configuration_profile] || {}
            s.merge!(
              :operating_system_flavor_id     => s[:direct_operating_system_flavor_id].presence ||
                                                 parent[:operating_system_flavor_id].presence,
              :customization_script_medium_id => s[:direct_customization_script_medium_id].presence ||
                                                 parent[:customization_script_medium_id].presence,
              :customization_script_ptable_id => s[:direct_customization_script_ptable_id].presence ||
                                                 parent[:customization_script_ptable_id].presence,
            )
            invalid = []
            invalid << "location" if s[:configuration_location_id].nil?
            invalid << "organization" if s[:configuration_organization_id].nil?
            $log.warn "Foreman host #{s[:hostname]} missing: #{invalid.join(", ")}" unless invalid.empty?
          end
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
            h[:parent_ref] = (m["ancestry"] || "").split("/").last.presence if m.key?("ancestry")
            h[extra_field.to_sym] = m[extra_field] if extra_field
          end
        end
      end

      def backfill_parent_ref(collection)
        collection.each do |rec|
          rec[:parent_ref] = derive_parent_ref(rec, collection) unless rec.key?(:parent_ref)
        end
      end

      # title = parent_title/name. we do this in reverse
      def derive_parent_ref(rec, collection)
        parent_title = (rec[:title] || "").sub(/\/?#{rec[:name]}/, "").presence
        collection.detect { |c| c[:title].to_s == parent_title }.try(:[], :manager_ref) if parent_title
      end

      # given an array of hashes, squash the values together, last value taking precidence
      def rollup(target, records)
        records.each do |record|
          target.merge!(record.select { |_n, v| !v.nil? && v != "" })
        end
      end

      # walk collection returning [ancestor, grand parent, parent, child_record]
      def family_tree(collection, record)
        ret = []
        loop do
          ret << record
          parent_ref = record[:parent_ref]
          return ret.reverse unless parent_ref
          record = collection.detect { |r| r[:manager_ref] == parent_ref }
        end
      end
    end
  end
end
