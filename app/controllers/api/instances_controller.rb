module Api
  class InstancesController < BaseController
    include Subcollections::LoadBalancers

    def terminate_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for terminating a #{type} resource" unless id

      api_action(type, id) do |klass|
        instance = resource_search(id, type, klass)
        api_log_info("Terminating #{instance_ident(instance)}")
        terminate_instance(instance)
      end
    end

    def stop_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for stopping a #{type} resource" unless id

      api_action(type, id) do |klass|
        instance = resource_search(id, type, klass)
        api_log_info("Stopping #{instance_ident(instance)}")

        result = validate_instance_for_action(instance, "stop")
        result = stop_instance(instance) if result[:success]
        result
      end
    end

    def start_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for starting a #{type} resource" unless id

      api_action(type, id) do |klass|
        instance = resource_search(id, type, klass)
        api_log_info("Starting #{instance_ident(instance)}")

        result = validate_instance_for_action(instance, "start")
        result = start_instance(instance) if result[:success]
        result
      end
    end

    def pause_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for pausing a #{type} resource" unless id

      api_action(type, id) do |klass|
        instance = resource_search(id, type, klass)
        api_log_info("Pausing #{instance_ident(instance)}")

        result = validate_instance_for_action(instance, "pause")
        result = pause_instance(instance) if result[:success]
        result
      end
    end

    def suspend_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for suspending a #{type} resource" unless id

      api_action(type, id) do |klass|
        instance = resource_search(id, type, klass)
        api_log_info("Suspending #{instance_ident(instance)}")

        result = validate_instance_for_action(instance, "suspend")
        result = suspend_instance(instance) if result[:success]
        result
      end
    end

    def shelve_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for shelving a #{type} resource" unless id

      api_action(type, id) do |klass|
        instance = resource_search(id, type, klass)
        api_log_info("Shelving #{instance_ident(instance)}")

        result = validate_instance_for_action(instance, "shelve")
        result = shelve_instance(instance) if result[:success]
        result
      end
    end

    def reboot_guest_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for rebooting a #{type} resource" unless id

      api_action(type, id) do |klass|
        instance = resource_search(id, type, klass)
        api_log_info("Rebooting #{instance_ident(instance)}")

        result = validate_instance_for_action(instance, "reboot_guest")
        result = reboot_guest_instance(instance) if result[:success]
        result
      end
    end

    def reset_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for resetting a #{type} resource" unless id

      api_action(type, id) do |klass|
        instance = resource_search(id, type, klass)
        api_log_info("Resetting #{instance_ident(instance)}")

        result = validate_instance_for_action(instance, "reset")
        result = reset_instance(instance) if result[:success]
        result
      end
    end

    private

    def instance_ident(instance)
      "Instance id:#{instance.id} name:'#{instance.name}'"
    end

    def terminate_instance(instance)
      desc = "#{instance_ident(instance)} terminating"
      task_id = queue_object_action(instance, desc, :method_name => "vm_destroy", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def stop_instance(instance)
      desc = "#{instance_ident(instance)} stopping"
      task_id = queue_object_action(instance, desc, :method_name => "stop", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def start_instance(instance)
      desc = "#{instance_ident(instance)} starting"
      task_id = queue_object_action(instance, desc, :method_name => "start", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def pause_instance(instance)
      desc = "#{instance_ident(instance)} pausing"
      task_id = queue_object_action(instance, desc, :method_name => "pause", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def validate_instance_for_action(instance, action)
      if instance.respond_to?("supports_#{action}?")
        action_result(instance.public_send("supports_#{action}?"), instance.unsupported_reason(action.to_sym))
      else
        validation = instance.send("validate_#{action}")
        action_result(validation[:available], validation[:message].to_s)
      end
    end

    def suspend_instance(instance)
      desc = "#{instance_ident(instance)} suspending"
      task_id = queue_object_action(instance, desc, :method_name => "suspend", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def shelve_instance(instance)
      desc = "#{instance_ident(instance)} shelving"
      task_id = queue_object_action(instance, desc, :method_name => "shelve", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def reboot_guest_instance(instance)
      desc = "#{instance_ident(instance)} rebooting"
      task_id = queue_object_action(instance, desc, :method_name => "reboot_guest", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def reset_instance(instance)
      desc = "#{instance_ident(instance)} resetting"
      task_id = queue_object_action(instance, desc, :method_name => "reset", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end
  end
end
