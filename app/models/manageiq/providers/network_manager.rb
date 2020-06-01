module ManageIQ::Providers
  class NetworkManager < BaseManager
    include SupportsFeatureMixin

    class << model_name
      define_method(:route_key) { "ems_networks" }
      define_method(:singular_route_key) { "ems_network" }
    end

    # cloud_subnets are defined on base class, because of virtual_total performance
    has_many :floating_ips,                       :foreign_key => :ems_id, :dependent => :destroy
    has_many :security_groups,                    :foreign_key => :ems_id, :dependent => :destroy
    has_many :security_policies,                  :foreign_key => :ems_id, :dependent => :destroy
    has_many :security_policy_rules,              :through => :security_policies
    has_many :firewall_rules,                     :through => :security_groups
    has_many :cloud_networks,                     :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_ports,                      :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_subnet_network_ports,         :through => :network_ports
    has_many :network_routers,                    :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_groups,                     :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_services,                   :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_service_entries,            :through => :network_services
    has_many :load_balancers,                     :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_pools,                :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_pool_member_pools,    :through => :load_balancer_pools
    has_many :load_balancer_pool_members,         :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_listeners,            :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_listener_pools,       :through => :load_balancer_listeners
    has_many :load_balancer_health_checks,        :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_health_check_members, :through => :load_balancer_health_checks

    alias all_cloud_networks cloud_networks

    def self.display_name(number = 1)
      n_('Network Manager', 'Network Managers', number)
    end
  end
end
