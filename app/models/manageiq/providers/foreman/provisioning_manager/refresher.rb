module ManageIQ::Providers
  module Foreman
    class ProvisioningManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin

      def parse_legacy_inventory(manager)
        manager.with_provider_connection do |connection|
          raw_ems_data = fetch_provisioning_inventory(connection)
          ProvisioningManager::RefreshParser.provisioning_inv_to_hashes(raw_ems_data)
        end
      end

      def save_inventory(manager, target, hashes)
        EmsRefresh.save_provisioning_manager_inventory(manager, hashes, target)
        EmsRefresh.queue_refresh(manager.provider.configuration_manager)
      end

      private

      def fetch_provisioning_inventory(connection)
        {
          :operating_systems => connection.all_with_details(:operatingsystems),
          :media             => connection.all(:media),
          :ptables           => connection.all(:ptables),
          :locations         => connection.all(:locations),
          :organizations     => connection.all(:organizations),
          :architectures     => connection.all(:architectures),
          :compute_profiles  => connection.all(:compute_profiles),
          :domains           => connection.all(:domains),
          :environments      => connection.all(:environments),
          :realms            => connection.all(:realms),
        }
      end
    end
  end
end
