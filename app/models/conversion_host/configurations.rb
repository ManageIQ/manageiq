module ConversionHost::Configurations
  extend ActiveSupport::Concern
  module ClassMethods
    def notify_configuration_result(op, success, resource_info)
      Notification.create(
        :type    => success ? :conversion_host_config_success : :conversion_host_config_failure,
        :options => {
          :op_name => op,
          :op_arg  => resource_info,
        }
      )
    end

    def queue_configuration(op, instance_id, resource, params, auth_user = nil)
      task_opts = {
        :action => "Configuring a conversion_host: operation=#{op} resource=(type: #{resource.class.name} id:#{resource.id})",
        :userid => auth_user
      }
      queue_opts = {
        :class_name  => name,
        :method_name => op,
        :instance_id => instance_id,
        :role        => 'ems_operations',
        :zone        => resource.ext_management_system.my_zone,
        :args        => [params]
      }
      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end

    def enable_queue(params, auth_user = nil)
      resource_type = params[:resource_type]
      resource_id = params[:resource_id]
      resource = resource_type.constantize.find(resource_id)

      queue_configuration('enable', nil, resource, params, auth_user)
    end

    def enable(params)
      _log.info("Enabling a conversion_host with parameters: #{params}")

      vddk_url = params.delete("param_v2v_vddk_package_url")
      resource_id = params[:resource_id]
      resource_type = params[:resource_type]
      resource = resource_type.constantize.find(resource_id)

      conversion_host = new(params.merge(:resource => resource))
      conversion_host.enable_conversion_host_role
      success = conversion_host.save!
    ensure
      resource_info = "type=#{params[:resource_type]} id=#{params[:resource_id]}"
      notify_configuration_result('enable', success, resource_info)
    end

    def self.disable_queue(params, auth_user = nil)
      id = params[:id]
      resource = find(id).resource
      queue_configuration('disable', id, resource, params, auth_user)
    end
  end

  def disable(params)
    resource_info = "type=#{resource.class.name} id=#{resource.id}"
    _log.info("Disabling a conversion_host #{resource_info} with parameters: #{params}")

    disable_conversion_host_role
    success = destroy!
  ensure
    self.class.notify_configuration_result('disable', success, resource_info)
  end
end
