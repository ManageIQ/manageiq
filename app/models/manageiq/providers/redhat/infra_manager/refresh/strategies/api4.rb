module ManageIQ::Providers::Redhat::InfraManager::Refresh::Strategies
  class Api4 < ManageIQ::Providers::Redhat::InfraManager::Refresh::Refresher
    attr_reader :ems

    def host_targeted_refresh(inventory, target)
      inventory.host_targeted_refresh(target)
    end

    def vm_targeted_refresh(inventory, target)
      inventory.vm_targeted_refresh(target)
    end

    require 'uri'

    def inventory_from_ovirt(ems)
      @ems = ems
      ManageIQ::Providers::Redhat::InfraManager::Inventory::Strategies::V4.new(:ems => ems)
    end
  end
end
