class ManagerRefresh::InventoryCollectionDefault::PhysicalInfraManager < ManagerRefresh::InventoryCollectionDefault
  class << self
    def physical_servers(extra_attributes = {})
      attributes = {
        :model_class    => ::PhysicalServer,
        :association    => :physical_servers,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id }
        }
      }

      attributes.merge!(extra_attributes)
    end

    def physical_server_details(extra_attributes = {})
      attributes = {
        :model_class                  => ::AssetDetail,
        :association                  => :physical_server_details,
        :manager_ref                  => [:resource],
        :parent_inventory_collections => [:physical_servers],
      }

      attributes.merge!(extra_attributes)
    end

    def computer_systems(extra_attributes = {})
      attributes = {
        :model_class                  => ::ComputerSystem,
        :association                  => :computer_systems,
        :manager_ref                  => [:managed_entity],
        :parent_inventory_collections => [:physical_servers],
      }

      attributes.merge!(extra_attributes)
    end

    def hardwares(extra_attributes = {})
      attributes = {
        :model_class                  => ::Hardware,
        :association                  => :hardwares,
        :manager_ref                  => [:computer_system],
        :parent_inventory_collections => [:physical_servers],
      }

      attributes.merge!(extra_attributes)
    end

    def physical_racks(extra_attributes = {})
      attributes = {
        :model_class    => ::PhysicalRack,
        :association    => :physical_racks,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id }
        }
      }

      attributes.merge!(extra_attributes)
    end

    def physical_chassis(extra_attributes = {})
      attributes = {
        :model_class    => ::PhysicalChassis,
        :association    => :physical_chassis,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id }
        }
      }

      attributes.merge!(extra_attributes)
    end
  end
end
