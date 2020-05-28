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

    # Configure a conversion host as a queued task. The queue name and the
    # queue zone are derived from the EMS of the resource. The op (method name),
    # instance id, resource and parameters are all mandatory. The auth user is
    # optional.
    #
    def queue_configuration(op, instance_id, resource, params, auth_user = nil)
      task_opts = {
        :action => "Configuring a conversion_host: operation=#{op} resource=(name: #{resource.name} type: #{resource.class.name} id: #{resource.id})",
        :userid => auth_user
      }

      queue_opts = {
        :class_name  => name,
        :method_name => op,
        :instance_id => instance_id,
        :role        => 'ems_operations',
        :zone        => resource.ext_management_system.my_zone,
        :queue_name  => resource.ext_management_system.queue_name_for_ems_operations,
        :args        => [params, auth_user]
      }

      task_id = MiqTask.generic_action_with_callback(task_opts, queue_opts)

      # Set the context_data after the fact because the above call only accepts
      # certain options while ignoring the rest. We also don't want to store
      # any ssh key information. Useful for a retry option in the UI, and
      # informational purposes in general.
      #
      MiqTask.find(task_id).tap do |task|
        params = params&.except(:task_id, :miq_task_id)
        params = params&.update(:auth_user => auth_user) if auth_user
        hash = {:request_params => params&.reject { |key, _value| key.to_s.end_with?('private_key') }}
        task.context_data = hash
        task.save
      end

      task_id
    end

    def enable_queue(params, auth_user = nil)
      params = params.symbolize_keys
      resource = params.delete(:resource)

      raise "#{resource.class.name.demodulize} '#{resource.name}' doesn't have a hostname or IP address in inventory" if resource.hostname.nil? && resource.ipaddresses.empty?
      raise "the resource '#{resource.name}' is already configured as a conversion host" if ConversionHost.exists?(:resource => resource)

      params[:resource_id] = resource.id
      params[:resource_type] = resource.class.base_class.name

      queue_configuration('enable', nil, resource, params, auth_user)
    end

    def enable(params, auth_user = nil)
      params = params.symbolize_keys
      _log.debug("Enabling a conversion_host with parameters: #{params}")

      params.delete(:task_id) # In case this is being called through *_queue which will stick in a :task_id
      miq_task_id = params.delete(:miq_task_id) # The miq_queue.activate_miq_task will stick in a :miq_task_id

      vmware_vddk_package_url = params.delete(:vmware_vddk_package_url)
      params[:vddk_transport_supported] = vmware_vddk_package_url.present?

      vmware_ssh_private_key = params.delete(:vmware_ssh_private_key)
      params[:ssh_transport_supported] = vmware_ssh_private_key.present?

      ssh_key = params.delete(:conversion_host_ssh_private_key)

      openstack_tls_ca_certs = params.delete(:openstack_tls_ca_certs)

      new(params).tap do |conversion_host|
        if ssh_key
          conversion_host.authentications << AuthPrivateKey.create!(
            :name     => conversion_host.name,
            :auth_key => ssh_key,
            :userid   => auth_user,
            :authtype => 'v2v'
          )
        end

        conversion_host.enable_conversion_host_role(vmware_vddk_package_url, vmware_ssh_private_key, openstack_tls_ca_certs, miq_task_id)
        conversion_host.save!

        if miq_task_id
          MiqTask.find(miq_task_id).tap do |task|
            task.context_data.to_h[:conversion_host_id] = conversion_host.id
            task.save
          end
        end
      end
    rescue StandardError => error
      raise
    ensure
      resource_info = "type=#{params[:resource_type]} id=#{params[:resource_id]}"
      notify_configuration_result('enable', error.nil?, resource_info)
    end
  end

  def disable_queue(auth_user = nil)
    self.class.queue_configuration('disable', id, resource, {}, auth_user)
  end

  def disable(_params = nil, _auth_user = nil)
    resource_info = "type=#{resource.class.name} id=#{resource.id}"
    raise "There are active migration tasks running on this conversion host" if active_tasks.present?

    _log.debug("Disabling a conversion_host #{resource_info}")
    disable_conversion_host_role
    destroy!
  rescue StandardError => error
    raise error
  ensure
    self.class.notify_configuration_result('disable', error.nil?, resource_info)
  end
end
