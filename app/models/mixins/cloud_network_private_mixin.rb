module CloudNetworkPrivateMixin
  extend ActiveSupport::Concern

  included do
    has_many :vms, :through => :network_ports, :source => :device, :source_type => 'VmOrTemplate'
    has_many :network_routers, :through => :network_ports, :source => :device, :source_type => 'NetworkRouter'
    has_many :public_networks, :through => :network_routers, :source => :cloud_network
  end
end
