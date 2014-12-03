class ApiController
  module Vms
    def vm_ident(vm)
      "VM id:#{vm.id} name:'#{vm.name}'"
    end

    def poweron_resource_vms(type, id = nil, _data = nil)
      cspec = collection_config[type]
      klass = cspec[:klass].constantize

      raise BadRequestError, "Must specify an id for powering on a #{type} resource" unless id
      vm = resource_search(id, type, klass)
      api_log_info("Powering on #{vm_ident(vm)}")

      result = validate_vm_for_action(vm, "start")
      result = poweron_vm(vm) if result[:success]

      result_href(result, type, id)
      log_result(result)
      result
    end

    private

    def validate_vm_for_action(vm, action)
      validation = vm.send("validate_#{action}")
      action_result(validation[:available], validation[:message].to_s)
    end

    def poweron_vm(vm)
      vm.start
      action_result(true, "#{vm_ident(vm)} starting")
      rescue => err
        action_result(false, err.to_s)
    end
  end
end
