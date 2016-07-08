module ManageIQ::Providers
  module Foreman
    class ConfigurationManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin

      def parse_legacy_inventory(manager)
        manager.with_provider_connection do |connection|
          raw_ems_data = fetch_configuration_inventory(connection)
          fetch_provisioning_manager_data(raw_ems_data, manager.provider.provisioning_manager)
          ConfigurationManager::RefreshParser.configuration_inv_to_hashes(raw_ems_data)
        end
      end

      def save_inventory(manager, target, hashes)
        EmsRefresh.save_configuration_manager_inventory(manager, hashes, target)
        EmsRefresh.queue_refresh(manager.provider.provisioning_manager) if hashes[:needs_provisioning_refresh]
      end

      private

      def fetch_configuration_inventory(connection)
        hosts = connection.all(:hosts)
        hostgroups = connection.all(:hostgroups)

        # if locations or organizations are enabled (detected by presence in host records)
        #    but it is not present in hostgroups
        #   fetch details for a hostgroups (to get location and organization information)
        host = hosts.first
        hostgroup = hostgroups.first
        if (host && hostgroup && (
            (host.key?("location_id") && !hostgroup.key?("locations")) ||
            (host.key?("organization_id") && !hostgroup.key?("organizations"))))
          hostgroups = connection.load_details(hostgroups, :hostgroups)
        end
        {
          :hosts      => hosts,
          :hostgroups => hostgroups
        }
      end

      # this data was fetched from the provisioning_refresher/provider
      # but the local data needs to link to it.
      # this method makes it available
      def fetch_provisioning_manager_data(hash, manager)
        hash.merge!(
          :ptables                  => manager_ref_hash(manager.customization_script_ptables),
          :media                    => manager_ref_hash(manager.customization_script_media),
          :operating_system_flavors => manager_ref_hash(manager.operating_system_flavors),
          :locations                => manager_ref_hash(manager.configuration_locations),
          :organizations            => manager_ref_hash(manager.configuration_organizations),
          :architectures            => manager_ref_hash(manager.configuration_architectures),
          :compute_profiles         => manager_ref_hash(manager.configuration_compute_profiles),
          :domains                  => manager_ref_hash(manager.configuration_domains),
          :environments             => manager_ref_hash(manager.configuration_environments),
          :realms                   => manager_ref_hash(manager.configuration_realms),
        )
      end

      def manager_ref_hash(records)
        Hash[records.collect { |r| [r.manager_ref, r.id] }]
      end
    end
  end
end
