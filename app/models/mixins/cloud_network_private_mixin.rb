module CloudNetworkPrivateMixin
  extend ActiveSupport::Concern

  included do
    has_many :vms, :through => :network_ports, :source => :device, :source_type => 'VmOrTemplate'
    has_many :network_routers, :through => :cloud_subnets
    has_many :public_networks, :through => :cloud_subnets
  end
end
