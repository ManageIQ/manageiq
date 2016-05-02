module ManageIQ::Providers
  class NetworkManager < BaseManager
    class << model_name
      define_method(:route_key) { "ems_networks" }
      define_method(:singular_route_key) { "ems_network" }
    end

    has_many :floating_ips,    :foreign_key => :ems_id, :dependent => :destroy
    has_many :security_groups, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_networks,  :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_subnets,   :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_ports,   :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_routers, :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_groups,  :foreign_key => :ems_id, :dependent => :destroy

    alias all_cloud_networks cloud_networks

    def total_subnets
      cloud_subnets.size
    end
    virtual_column :total_subnets, :type => :integer, :uses => :cloud_subnets
  end
end
