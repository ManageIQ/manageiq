module MiqAeMethodService
  class MiqAeServiceServiceTemplate < MiqAeServiceModelBase
    expose :service_templates, :association => true
    expose :services,          :association => true
    expose :service_resources, :association => true
    expose :tenant,            :association => true

    def owner=(owner)
      if owner.nil? || owner.kind_of?(MiqAeMethodService::MiqAeServiceUser)
        if owner.nil?
          @object.evm_owner = nil
        else
          @object.evm_owner = User.find_by(:id => owner.id)
        end
        @object.save
      end
    end

    def group=(group)
      if group.nil? || group.kind_of?(MiqAeMethodService::MiqAeServiceMiqGroup)
        if group.nil?
          @object.miq_group = nil
        else
          @object.miq_group = MiqGroup.find_by(:id => group.id)
        end
        @object.save
      end
    end
  end
end
