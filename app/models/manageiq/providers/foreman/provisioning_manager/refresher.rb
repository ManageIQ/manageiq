module ManageIQ::Providers
  module Foreman
    class ProvisioningManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin

      def parse_legacy_inventory(manager)
        manager.with_provider_connection do |connection|
          raw_ems_data = connection.inventory.refresh_provisioning
          ProvisioningManager::RefreshParser.provisioning_inv_to_hashes(raw_ems_data)
        end
      end

      def save_inventory(manager, target, hashes)
        EmsRefresh.save_provisioning_manager_inventory(manager, hashes, target)
        EmsRefresh.queue_refresh(manager.provider.configuration_manager)
      end
    end
  end
end
