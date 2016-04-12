module ManageIQ::Providers
  module Foreman
    class ConfigurationManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin

      def parse_legacy_inventory(manager)
        manager.with_provider_connection do |connection|
          raw_ems_data = connection.inventory.refresh_configuration
          fetch_provisioning_manager_data(raw_ems_data, manager.provider.provisioning_manager)
          ConfigurationManager::RefreshParser.configuration_inv_to_hashes(raw_ems_data)
        end
      end

      def save_inventory(manager, target, hashes)
        EmsRefresh.save_configuration_manager_inventory(manager, hashes, target)
        EmsRefresh.queue_refresh(manager.provider.provisioning_manager) if hashes[:needs_provisioning_refresh]
      end

      private

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
