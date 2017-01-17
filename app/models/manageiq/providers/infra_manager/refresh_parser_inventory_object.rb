class ManageIQ::Providers::InfraManager::RefreshParserInventoryObject < ::ManagerRefresh::RefreshParserInventoryObject
    def add_inventory_collection(model_class, association, manager_ref = nil)
      delete_method = model_class.new.respond_to?(:disconnect_inv) ? :disconnect_inv : nil

      ::ManagerRefresh::InventoryCollection.new(model_class,
                                                :parent        => @ems,
                                                :association   => association,
                                                :manager_ref   => manager_ref,
                                                :delete_method => delete_method)
    end
end
