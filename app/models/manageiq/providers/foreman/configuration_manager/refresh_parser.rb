module ManageIQ::Providers
  module Foreman
    class ConfigurationManager::RefreshParser
      include Vmdb::Logging

      # we referenced a record that does not exist in the database
      attr_accessor :needs_provisioning_refresh

      def self.configuration_inv_to_hashes(inv)
        new.configuration_inv_to_hashes(inv)
      end

      # data coming in from foreman:
      #   :hostgroups
      #   :hosts
      # data coming in from database (already in the form of ids)
      #   see indexes variable
      def configuration_inv_to_hashes(inv)
        indexes = {
          :flavors          => inv[:operating_system_flavors],
          :media            => inv[:media],
          :ptables          => inv[:ptables],
          :locations        => inv[:locations],
          :organizations    => inv[:organizations],
          :architectures    => inv[:architectures],
          :compute_profiles => inv[:compute_profiles],
          :domains          => inv[:domains],
          :environments     => inv[:environments],
          :realms           => inv[:realms],
        }

        {
          :configuration_profiles     => configuration_profile_inv_to_hashes(inv[:hostgroups], indexes),
          :configured_systems         => configured_system_inv_to_hashes(inv[:hosts], indexes),
          :needs_provisioning_refresh => needs_provisioning_refresh,
        }
      end

      def configuration_profile_inv_to_hashes(recs, indexes)
        # if locations have a key with 0 (meaning we're using default), then lets assign a default location
        def_loc = tax_refs if indexes[:locations].keys == %w(0)
        def_org = tax_refs if indexes[:organizations].keys == %w(0)
        recs.collect do |profile|
          {
            :type                                  => "ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile",
            :manager_ref                           => profile["id"].to_s,
            :parent_ref                            => (profile["ancestry"] || "").split("/").last.presence,
            :name                                  => profile["name"],
            :description                           => profile["title"],
            :direct_configuration_tag_ids          => tag_id_lookup(indexes, profile),
            :configuration_tags_hash               => tag_hash(profile),
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

            configuration_tag_hashes = family_tree(profiles, p).map do |hash|
              hash[:configuration_tags_hash]
            end
            p[:configuration_tag_ids] = tag_id_lookup(indexes, rollup({}, configuration_tag_hashes))

            invalid = []
            invalid << "location" if p[:configuration_location_ids].empty?
            invalid << "organization" if p[:configuration_organization_ids].empty?
            _log.warn "hostgroup #{p[:name]} missing: #{invalid.join(", ")}" unless invalid.empty?
          end
          profiles.each { |p| p.delete(:configuration_tags_hash) }
          indexes[:profiles] = add_ids(profiles)
        end
      end

      def configured_system_inv_to_hashes(recs, indexes)
        def_loc = 0 if indexes[:locations].keys == %w(0)
        def_org = 0 if indexes[:organizations].keys == %w(0)
        recs.collect do |cs|
          {
            :type                                  => "ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem",
            :manager_ref                           => cs["id"].to_s,
            :hostname                              => cs["name"],
            :configuration_profile                 => id_lookup(indexes[:profiles], cs["hostgroup_id"]),
            :direct_operating_system_flavor_id     => id_lookup(indexes[:flavors], cs["operatingsystem_id"]),
            :direct_customization_script_medium_id => id_lookup(indexes[:media], cs["medium_id"]),
            :direct_customization_script_ptable_id => id_lookup(indexes[:ptables], cs["ptable_id"]),
            :direct_configuration_tag_ids          => tag_id_lookup(indexes, cs),
            :configuration_tags_hash               => tag_hash(cs),
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
            configuration_tag_hashes = family_tree(systems, s).map do |hash|
              hash[:configuration_tags_hash]
            end
            s.merge!(
              :operating_system_flavor_id     => s[:direct_operating_system_flavor_id].presence ||
                                                 parent[:operating_system_flavor_id].presence,
              :customization_script_medium_id => s[:direct_customization_script_medium_id].presence ||
                                                 parent[:customization_script_medium_id].presence,
              :customization_script_ptable_id => s[:direct_customization_script_ptable_id].presence ||
                                                 parent[:customization_script_ptable_id].presence,
              :configuration_tag_ids          => tag_id_lookup(indexes, rollup({}, configuration_tag_hashes)),
            )

            invalid = []
            invalid << "location" if s[:configuration_location_id].nil?
            invalid << "organization" if s[:configuration_organization_id].nil?
            _log.warn "host #{s[:hostname]} missing: #{invalid.join(", ")}" unless invalid.empty?
          end
          systems.each { |s| s.delete(:configuration_tags_hash) }
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

      # given an array of hashes, squash the values together, last value taking precidence
      def rollup(target, records)
        records.each do |record|
          target.merge!(record.select { |_n, v| !v.nil? && v != "" })
        end
        target
      end

      # lookup all the configuration_tags and return ids (from the indexes)
      def tag_id_lookup(indexes, record)
        [
          id_lookup(indexes[:architectures], record["architecture_id"]),
          id_lookup(indexes[:compute_profiles], record["compute_profile_id"]),
          id_lookup(indexes[:domains], record["domain_id"]),
          id_lookup(indexes[:environments], record["environment_id"]),
          id_lookup(indexes[:realms], record["realm_id"]),
        ].compact
      end

      # produce temporary hash of all the tags
      def tag_hash(record)
        record.slice(*%w(architecture_id compute_profile_id
                          domain_id environment_id realm_id)).delete_if { |_n, v| v.nil? }
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
