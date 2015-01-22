require 'manageiq_foreman/inventory'

module EmsRefresh
  module Refreshers
    class ForemanConfigurationRefresher < BaseRefresher
      include EmsRefresherMixin

      def parse_inventory(manager, targets)
        foreman = ManageiqForeman::Inventory.from_attributes(manager.connection_attrs)
        raw_ems_data = foreman.refresh_configuration(targets)
        fetch_provisioning_manager_data(raw_ems_data, manager.provider.provisioning_manager)
        EmsRefresh::Parsers::Foreman.configuration_inv_to_hashes(raw_ems_data)
      end

      def save_inventory(manager, targets, hashes)
        EmsRefresh.save_configuration_manager_inventory(manager, hashes, targets[0])
        EmsRefresh.refresh(manager.provider.provisioning_manager, targets[0]) if hashes[:missing_key]
      end

      private

      def fetch_provisioning_manager_data(hash, manager)
        hash[:customization_scripts] = Hash[manager.customization_scripts.map { |r| [r.manager_ref, r.id] }]
        hash[:operating_system_flavors] = Hash[manager.operating_system_flavors.map { |r| [r.manager_ref, r.id] }]
      end
    end
  end
end
