class ApiController
  module Vms
    def vm_identity(vm)
      "VM id:#{vm.id} name:'#{vm.name}'"
    end

    def poweron_resource_vms(type, id = nil, data = nil)
      cspec = collection_config[type]
      klass = cspec[:klass].constantize
      if id
        vm = resource_search(id, type, klass)
        vm_ident = vm_identity(vm)
        api_log_info("Powering on #{vm_ident}")
        result =
          if vm.state == "on"
            action_result(false, "#{vm_ident} is already powered on")
          else
            begin
              vm.start
              action_result(true, "#{vm_ident} starting")
            rescue => err
              action_result(false, err.to_s)
            end
          end
        result_href(result, type, id)
        log_result(result)
        result
      else
        raise BadRequestError, "Must specify an id for powering on a #{type} resource"
      end
    end
  end
end
