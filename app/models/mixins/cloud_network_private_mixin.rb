module CloudNetworkPrivateMixin
  extend ActiveSupport::Concern

  included do
    has_many :vms, :through => :network_ports, :source => :device, :source_type => 'VmOrTemplate'
    has_many :network_routers, :through => :network_ports, :source => :device, :source_type => 'NetworkRouter'
    has_many :public_networks, :through => :network_routers, :source => :cloud_network
  end

  def ip_address_used_count(reload = false)
    @ip_address_used_count = nil if reload
    # Number of VMs should be number of used Fixed ips, this applies only for Private Network
    @ip_address_used_count ||= vms.count
  end

  def ip_address_used_count_live(reload = false)
    @ip_address_used_count_live = nil if reload
    # Number of ports with fixed IPs plugged into the network. Live means it talks directly to OpenStack API
    # TODO(lsmola) we probably need paginated API call, there should be no multitenancy needed, but the current
    # UI code allows to mix tenants, so it could be needed, athough netron doesn seem to have --all-tenants calls,
    # so when I use admin, I can see other tenant resources. Investigate, fix.
    @ip_address_used_count_live ||= ext_management_system.with_provider_connection(
                                      :service => "Network", :tenant_name => cloud_tenant.name) do |connection|
      connection.ports.all(:network_id => ems_ref, :device_owner => "compute:None").count
    end
  end
end
