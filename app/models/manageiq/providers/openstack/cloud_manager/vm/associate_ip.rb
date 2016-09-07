module ManageIQ::Providers::Openstack::CloudManager::Vm::AssociateIp
  extend ActiveSupport::Concern

  included do
    supports :associate_floating_ip do
      if cloud_tenant.nil? || cloud_tenant.floating_ips.empty?
        unsupported_reason_add(:associate_floating_ip,
                               _("There are no %{floating_ips} available to this %{instance}.") % {
                                 :floating_ips => ui_lookup(:tables => "floating_ips"),
                                 :instance     => ui_lookup(:table => "vm_cloud")
                               })
      end
    end
    supports :disassociate_floating_ip do
      if floating_ips.empty?
        unsupported_reason_add(:disassociate_floating_ip,
                               _("This %{instance} does not have any associated %{floating_ips}") % {
                                 :instance     => ui_lookup(:table => 'vm_cloud'),
                                 :floating_ips => ui_lookup(:tables => 'floating_ip')
                               })
      end
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
