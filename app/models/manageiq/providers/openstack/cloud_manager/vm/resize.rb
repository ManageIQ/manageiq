module ManageIQ::Providers::Openstack::CloudManager::Vm::Resize
  def validate_resize
    %w(ACTIVE SHUTOFF).include? raw_power_state
  end

  def raw_resize(new_flavor)
    ext_management_system.with_provider_connection(compute_connection_options) do |service|
      service.resize_server(ems_ref, new_flavor.ems_ref)
    end
    MiqQueue.put(:class_name  => self.class.name,
                 :expires_on  => Time.now.utc + 4.hours,
                 :instance_id => id,
                 :method_name => "raw_resize_finish")
  rescue => err
    _log.error "vm=[#{name}], flavor=[#{new_flavor.name}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, err.to_s, err.backtrace
  end

  def validate_resize_confirm
    raw_power_state == 'VERIFY_RESIZE'
  end

  def raw_resize_confirm
    ext_management_system.with_provider_connection(compute_connection_options) do |service|
      service.confirm_resize_server(ems_ref)
    end
  rescue => err
    _log.error "vm=[#{name}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, err.to_s, err.backtrace
  end

  def raw_resize_finish
    raise MiqException::MiqQueueRetryLater.new(:deliver_on => Time.now.utc + 2.minutes) unless validate_resize_confirm
    raw_resize_confirm
  end

  def validate_resize_revert
    raw_power_state == 'VERIFY_RESIZE'
  end

  def raw_resize_revert
    ext_management_system.with_provider_connection(compute_connection_options) do |service|
      service.revert_resize_server(ems_ref)
    end
  rescue => err
    _log.error "vm=[#{name}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, err.to_s, err.backtrace
  end

  def compute_connection_options
    {:service => 'Compute', :tenant_name => cloud_tenant.name}
  end
end
