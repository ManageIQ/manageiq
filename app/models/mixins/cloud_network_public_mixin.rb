module CloudNetworkPublicMixin
  extend ActiveSupport::Concern

  included do
    has_many :vms, :through => :network_routers
    has_many :network_routers, :foreign_key => :cloud_network_id
    has_many :private_networks, :through => :network_routers, :source => :cloud_networks
  end
end
