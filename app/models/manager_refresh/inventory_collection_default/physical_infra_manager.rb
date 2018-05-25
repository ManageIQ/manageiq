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
  end
end
