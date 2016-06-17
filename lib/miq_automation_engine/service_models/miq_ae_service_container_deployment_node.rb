module MiqAeMethodService
  class MiqAeServiceContainerDeploymentNode < MiqAeServiceModelBase
    expose :vm_id
    expose :is_tagged_with?
    expose :tags

    def add_vm(vm_id)
      ar_method do
        wrap_results(@object.vm_id = vm_id)
        @object.save!
      end
    end
  end
end
