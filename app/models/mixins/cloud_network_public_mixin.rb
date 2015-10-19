module CloudNetworkPublicMixin
  extend ActiveSupport::Concern

  included do
    has_many :vms, :through => :network_routers
    has_many :network_routers, :foreign_key => :cloud_network_id
    has_many :private_networks, :through => :network_routers, :source => :cloud_networks
  end

  def ip_address_used_count(reload = false)
    @ip_address_used_count = nil if reload
    # Number of all floating Ips, since we are doing association by creating FloatingIP, because
    # associate is not atomic.
    @ip_address_used_count ||= floating_ips.count
  end

  def ip_address_used_count_live(reload = false)
    @ip_address_used_count_live = nil if reload
    # Number of ports with fixed IPs plugged into the network. Live means it talks directly to OpenStack API
    # TODO(lsmola) we probably need paginated API call, there should be no multitenancy needed, but the current
    # UI code allows to mix tenants, so it could be needed, athough netron doesn seem to have --all-tenants calls,
    # so when I use admin, I can see other tenant resources. Investigate, fix.
    @ip_address_used_count_live ||= ext_management_system.with_provider_connection(
                                      :service => "Network", :tenant_name => cloud_tenant.name) do |connection|
      connection.floating_ips.all(:floating_network_id => ems_ref).count
    end
  end
end
