module ManageIQ::Providers
  module Foreman
    class ProvisioningManager::RefreshParser
      include Vmdb::Logging

      def self.provisioning_inv_to_hashes(inv)
        new.provisioning_inv_to_hashes(inv)
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
        architectures    = architectures_inv_to_hashes(inv[:architectures])
        compute_profiles = compute_profiles_inv_to_hashes(inv[:compute_profiles])
        domains          = domains_inv_to_hashes(inv[:domains])
        environments     = environments_inv_to_hashes(inv[:environments])
        realms           = realms_inv_to_hashes(inv[:realms])

        indexes = {
          :media            => add_ids(media),
          :ptables          => add_ids(ptables),
          :architectures    => add_ids(architectures),
          :compute_profiles => add_ids(compute_profiles),
          :domains          => add_ids(domains),
          :environments     => add_ids(environments),
          :realms           => add_ids(realms),
        }

        {
          :customization_scripts       => media + ptables,
          :operating_system_flavors    => operating_system_flavors_inv_to_hashes(inv[:operating_systems], indexes),
          :configuration_locations     => location_inv_to_hashes(inv[:locations]),
          :configuration_organizations => organization_inv_to_hashes(inv[:organizations]),
          :configuration_tags          => architectures + compute_profiles + domains + environments + realms,
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

      private

      def add_ids(recs, key = :manager_ref)
        recs.each_with_object({}) { |r, target| target[r[key]] = r }
      end

      def id_lookup(ids, key)
        return unless key
        ids[key.to_s]
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
    end
  end
end
