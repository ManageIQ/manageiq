class ManagerRefresh::InventoryCollectionDefault::NetworkManager < ManagerRefresh::InventoryCollectionDefault
  class << self
    def cloud_subnet_network_ports(extra_attributes = {})
      attributes = {
        :model_class => ::CloudSubnetNetworkPort,
        :manager_ref => [:address, :cloud_subnet, :network_port],
        :association => :cloud_subnet_network_ports,
      }

      attributes.merge!(extra_attributes)
    end

    def network_ports(extra_attributes = {})
      attributes = {
        :model_class => ::NetworkPort,
        :association => :network_ports,
      }

      attributes.merge!(extra_attributes)
    end

    def floating_ips(extra_attributes = {})
      attributes = {
        :model_class => ::FloatingIp,
        :association => :floating_ips,
      }

      attributes.merge!(extra_attributes)
    end

    def cloud_subnets(extra_attributes = {})
      attributes = {
        :model_class => ::CloudSubnet,
        :association => :cloud_subnets,
      }

      attributes.merge!(extra_attributes)
    end

    def cloud_networks(extra_attributes = {})
      attributes = {
        :model_class => ::CloudNetwork,
        :association => :cloud_networks,
      }

      attributes.merge!(extra_attributes)
    end

    def security_groups(extra_attributes = {})
      attributes = {
        :model_class => ::SecurityGroup,
        :association => :security_groups,
      }

      attributes.merge!(extra_attributes)
    end

    def firewall_rules(extra_attributes = {})
      attributes = {
        :model_class => ::FirewallRule,
        :manager_ref => [:resource, :source_security_group, :direction, :host_protocol, :port, :end_port, :source_ip_range],
        :association => :firewall_rules,
      }

      attributes.merge!(extra_attributes)
    end

    def load_balancers(extra_attributes = {})
      attributes = {
        :model_class => ::LoadBalancer,
        :association => :load_balancers,
      }

      attributes.merge!(extra_attributes)
    end

    def load_balancer_pools(extra_attributes = {})
      attributes = {
        :model_class => ::LoadBalancerPool,
        :association => :load_balancer_pools,
      }

      attributes.merge!(extra_attributes)
    end

    def load_balancer_pool_members(extra_attributes = {})
      attributes = {
        :model_class => ::LoadBalancerPoolMember,
        :association => :load_balancer_pool_members,
      }

      attributes.merge!(extra_attributes)
    end

    def load_balancer_pool_member_pools(extra_attributes = {})
      attributes = {
        :model_class => ::LoadBalancerPoolMemberPool,
        :manager_ref => [:load_balancer_pool, :load_balancer_pool_member],
        :association => :load_balancer_pool_member_pools,
      }

      attributes.merge!(extra_attributes)
    end

    def load_balancer_listeners(extra_attributes = {})
      attributes = {
        :model_class => ::LoadBalancerListener,
        :association => :load_balancer_listeners,
      }

      attributes.merge!(extra_attributes)
    end

    def load_balancer_listener_pools(extra_attributes = {})
      attributes = {
        :model_class => ::LoadBalancerListenerPool,
        :manager_ref => [:load_balancer_listener, :load_balancer_pool],
        :association => :load_balancer_listener_pools,
      }

      attributes.merge!(extra_attributes)
    end

    def load_balancer_health_checks(extra_attributes = {})
      attributes = {
        :model_class => ::LoadBalancerHealthCheck,
        :association => :load_balancer_health_checks,
      }

      attributes.merge!(extra_attributes)
    end

    def load_balancer_health_check_members(extra_attributes = {})
      attributes = {
        :model_class => ::LoadBalancerHealthCheckMember,
        :manager_ref => [:load_balancer_health_check, :load_balancer_pool_member],
        :association => :load_balancer_health_check_members,
      }

      attributes.merge!(extra_attributes)
    end
  end
end
