module ManageIQ::Providers::Openstack::CloudManager::Vm::Resize
  def validate_resize
    msg = validate_vm_control
    return {:available => msg[0], :message => msg[1]} unless msg.nil?
    return {:available => true, :message => nil} if %w(ACTIVE SHUTOFF).include?(raw_power_state)
    {:available => false, :message => _("The Instance cannot be resized, current state has to be active or shutoff.")}
  end

  def raw_resize(new_flavor)
    # TODO(maufart): check if a new flavor disk space is not smaller that the actual one?
    ext_management_system.with_provider_connection(compute_connection_options) do |service|
      service.resize_server(ems_ref, new_flavor.ems_ref)
    end
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
