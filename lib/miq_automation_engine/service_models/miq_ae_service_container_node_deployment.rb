module MiqAeMethodService
  class MiqAeServiceContainerNodeDeployment < MiqAeServiceModelBase
    expose :vm, :association => true

    def add_vm(vm)
      ar_method { wrap_results(@object.vm = Vm.find(vm.id)) }
    end
  end
end
