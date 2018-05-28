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
  end
end
