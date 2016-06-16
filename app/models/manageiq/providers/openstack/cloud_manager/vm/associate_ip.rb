module ManageIQ::Providers::Openstack::CloudManager::Vm::AssociateIp
  def validate_associate_address
    {:available => true, :message => nil}
  end

  def validate_disassociate_address
    {:available => true, :message => nil}
  end

  def raw_associate_address(floating_ip)
    ext_management_system.with_provider_connection(compute_connection_options) do |connection|
      connection.associate_address(ems_ref, floating_ip)
    end
  rescue => err
    _log.error "vm=[#{name}], floating_ip=[#{floating_ip}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, err.to_s, err.backtrace
  end

  def raw_disassociate_address(floating_ip)
    ext_management_system.with_provider_connection(compute_connection_options) do |connection|
      connection.disassociate_address(ems_ref, floating_ip)
    end
  rescue => err
    _log.error "vm=[#{name}], floating_ip=[#{floating_ip}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, err.to_s, err.backtrace
  end

  def compute_connection_options
    {:service => 'Compute', :tenant_name => cloud_tenant.name}
  end
end
