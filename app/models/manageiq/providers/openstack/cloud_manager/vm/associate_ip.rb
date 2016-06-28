module ManageIQ::Providers::Openstack::CloudManager::Vm::AssociateIp
  def validate_associate_floating_ip
    if cloud_tenant.nil? || Rbac.filtered(cloud_tenant.floating_ips).empty?
      message = _("There are no %{floating_ips} available to this %{instance}.") % {
        :floating_ips => ui_lookup(:tables => "floating_ips"),
        :instance     => ui_lookup(:table => "vm_cloud")
      }
      {:available => false, :message => message}
    else
      {:available => true, :message => nil}
    end
  end

  def validate_disassociate_floating_ip
    if floating_ips.empty?
      message = _("This %{instance} does not have any associated %{floating_ips}") % {
        :instance     => ui_lookup(:table => 'vm_cloud'),
        :name         => name,
        :floating_ips => ui_lookup(:tables => 'floating_ip')
      }
      {:available => false, :message => message}
    else
      {:available => true, :message => nil}
    end
  end

  def raw_associate_floating_ip(floating_ip)
    ext_management_system.with_provider_connection(compute_connection_options) do |connection|
      connection.associate_address(ems_ref, floating_ip)
    end
  rescue => err
    _log.error "vm=[#{name}], floating_ip=[#{floating_ip}], error: #{err}"
    raise MiqException::MiqOpenstackApiRequestError, err.to_s, err.backtrace
  end

  def raw_disassociate_floating_ip(floating_ip)
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
