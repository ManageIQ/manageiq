module ManageIQ::Providers
  module Foreman
    class ProvisioningManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin

      def parse_inventory(manager, targets)
        manager.with_provider_connection do |connection|
          raw_ems_data = connection.inventory.refresh_provisioning(targets)
          ProvisioningManager::RefreshParser.provisioning_inv_to_hashes(raw_ems_data)
        end
      end

      def save_inventory(manager, targets, hashes)
        EmsRefresh.save_provisioning_manager_inventory(manager, hashes, targets[0])
        EmsRefresh.queue_refresh(manager.provider.configuration_manager)
      end
    end
  end
end
