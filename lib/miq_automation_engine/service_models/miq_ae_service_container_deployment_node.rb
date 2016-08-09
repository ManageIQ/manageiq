module MiqAeMethodService
  class MiqAeServiceContainerDeploymentNode < MiqAeServiceModelBase
    expose :vm_id
    expose :is_tagged_with?
    expose :tags
    expose :node_address

    def add_vm(vm_id)
      ar_method do
        @object.vm_id = vm_id
        @object.save!
      end
    end
  end
end
