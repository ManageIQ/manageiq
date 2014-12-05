class ApiController
  module Vms
    def start_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for starting a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Starting #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "start")
        result = start_vm(vm, klass) if result[:success]
        result
      end
    end

    def stop_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for stopping a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Stopping #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "stop")
        result = stop_vm(vm, klass) if result[:success]
        result
      end
    end

    def suspend_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for suspending a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Suspending #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "suspend")
        result = suspend_vm(vm, klass) if result[:success]
        result
      end
    end

    def delete_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for deleting a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Deleting #{vm_ident(vm)}")

        destroy_vm(vm)
      end
    end

    private

    def vm_ident(vm)
      "VM id:#{vm.id} name:'#{vm.name}'"
    end

    def validate_vm_for_action(vm, action)
      validation = vm.send("validate_#{action}")
      action_result(validation[:available], validation[:message].to_s)
    end

    def start_vm(vm, klass)
      desc = "#{vm_ident(vm)} starting"
      task_id = queue_object_action(vm,
                                    desc,
                                    :class_name  => klass.name,
                                    :method_name => "start",
                                    :role        => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def stop_vm(vm, klass)
      desc = "#{vm_ident(vm)} stopping"
      task_id = queue_object_action(vm,
                                    desc,
                                    :class_name  => klass.name,
                                    :method_name => "stop",
                                    :role        => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def suspend_vm(vm, klass)
      desc = "#{vm_ident(vm)} suspending"
      task_id = queue_object_action(vm,
                                    desc,
                                    :class_name  => klass.name,
                                    :method_name => "suspend",
                                    :role        => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def destroy_vm(vm)
      desc = "#{vm_ident(vm)} deleting"
      task_id = queue_object_action(vm, desc, :method_name => "destroy")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end
  end
end
