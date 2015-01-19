require 'manageiq_foreman/inventory'

module EmsRefresh
  module Refreshers
    class ForemanProvisioningRefresher < BaseRefresher
      include EmsRefresherMixin
      include RefresherRelatsMixin

      def parse_inventory(manager, targets)
        foreman = ManageiqForeman::Inventory.from_attributes(manager.connection_attrs)
        raw_ems_data = foreman.refresh_provisioning(targets)
        EmsRefresh::Parsers::Foreman.provisioning_inv_to_hashes(raw_ems_data)
      end

      def save_inventory(manager, targets, hashes)
        EmsRefresh.save_provisioning_manager_inventory(manager, hashes, targets[0])
      end
    end
  end
end
