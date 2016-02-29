module ManageIQ::Providers
  class NetworkManager < BaseManager
    class << model_name
      # define_method(:route_key) { "ems_networks" }
      # define_method(:singular_route_key) { "ems_network" }
      # TODO(lsmola) NetworkManager, has to be changed to ems_networks, once we have UI  and Controllers for IT
      define_method(:route_key) { "ems_clouds" }
      define_method(:singular_route_key) { "ems_cloud" }
    end

    has_many :floating_ips,    :foreign_key => :ems_id, :dependent => :destroy
    has_many :security_groups, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_networks,  :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_subnets,   :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_ports,   :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_routers, :foreign_key => :ems_id, :dependent => :destroy

    alias_method :all_cloud_networks, :cloud_networks
  end
end
