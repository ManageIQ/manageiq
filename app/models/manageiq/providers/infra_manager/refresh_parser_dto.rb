class ManageIQ::Providers::InfraManager::RefreshParserDto < ::ManagerRefresh::RefreshParserDto
    def add_dto_collection(model_class, association, manager_ref = nil)
      delete_method = model_class.new.respond_to?(:disconnect_inv) ? :disconnect_inv : nil

      ::ManagerRefresh::DtoCollection.new(model_class,
                                          :parent        => @ems,
                                          :association   => association,
                                          :manager_ref   => manager_ref,
                                          :delete_method => delete_method)
    end
end
