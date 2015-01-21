require 'manageiq_foreman/inventory'

module EmsRefresh
  module Refreshers
    class ForemanConfigurationRefresher < BaseRefresher
      include EmsRefresherMixin
      include RefresherRelatsMixin

      def parse_inventory(manager, targets)
        foreman = ManageiqForeman::Inventory.from_attributes(manager.connection_attrs)
        raw_ems_data = foreman.refresh_configuration(targets)
        EmsRefresh::Parsers::Foreman.configuration_inv_to_hashes(raw_ems_data, manager.provider.provisioning_manager)
      end

      def save_inventory(manager, targets, hashes)
        EmsRefresh.save_configuration_manager_inventory(manager, hashes, targets[0])
        EmsRefresh.refresh(manager.provider.provisioning_manager) if hashes[:missing_key]
      end
    end
  end
end
