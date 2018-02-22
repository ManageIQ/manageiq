class ManagerRefresh::InventoryCollectionDefault::NetworkManager < ManagerRefresh::InventoryCollectionDefault
  class << self
    def cloud_subnet_network_ports(extra_attributes = {})
      attributes = {
        :model_class                  => ::CloudSubnetNetworkPort,
        :manager_ref                  => [:address, :cloud_subnet, :network_port],
        :association                  => :cloud_subnet_network_ports,
        :parent_inventory_collections => [:vms, :network_ports, :load_balancers],
      }

      extra_attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.cloud_subnet_network_ports.references(:network_ports).where(
          :network_ports => {:ems_ref => manager_uuids}
        )
      end

      attributes.merge!(extra_attributes)
    end

    def network_ports(extra_attributes = {})
      attributes = {
        :model_class    => ::NetworkPort,
        :association    => :network_ports,
        :use_ar_object  => true,
        # TODO(lsmola) can't do batch strategy for network_ports because of security_groups relation
        :saver_strategy => :default,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.try(:network_manager).try(:id) || persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def floating_ips(extra_attributes = {})
      attributes = {
        :model_class    => ::FloatingIp,
        :association    => :floating_ips,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.try(:network_manager).try(:id) || persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def cloud_subnets(extra_attributes = {})
      attributes = {
        :model_class    => ::CloudSubnet,
        :association    => :cloud_subnets,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.try(:network_manager).try(:id) || persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def cloud_networks(extra_attributes = {})
      attributes = {
        :model_class    => ::CloudNetwork,
        :association    => :cloud_networks,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.try(:network_manager).try(:id) || persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def security_groups(extra_attributes = {})
      attributes = {
        :model_class    => ::SecurityGroup,
        :association    => :security_groups,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.try(:network_manager).try(:id) || persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def firewall_rules(extra_attributes = {})
      attributes = {
        :model_class                  => ::FirewallRule,
        :manager_ref                  => [:resource, :source_security_group, :direction, :host_protocol, :port, :end_port, :source_ip_range],
        :association                  => :firewall_rules,
        :parent_inventory_collections => [:security_groups],
      }

      attributes.merge!(extra_attributes)
    end

    def load_balancers(extra_attributes = {})
      attributes = {
        :model_class    => ::LoadBalancer,
        :association    => :load_balancers,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.try(:network_manager).try(:id) || persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def load_balancer_pools(extra_attributes = {})
      attributes = {
        :model_class                  => ::LoadBalancerPool,
        :association                  => :load_balancer_pools,
        :parent_inventory_collections => [:load_balancers],
        :builder_params               => {
          :ems_id => ->(persister) { persister.manager.try(:network_manager).try(:id) || persister.manager.id },
        }
      }

      extra_attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.load_balancer_pools.where(:ems_ref => manager_uuids)
      end

      attributes.merge!(extra_attributes)
    end

    def load_balancer_pool_members(extra_attributes = {})
      attributes = {
        :model_class                  => ::LoadBalancerPoolMember,
        :association                  => :load_balancer_pool_members,
        :parent_inventory_collections => [:load_balancers],
        :builder_params               => {
          :ems_id => ->(persister) { persister.manager.try(:network_manager).try(:id) || persister.manager.id },
        }
      }

      extra_attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.load_balancer_pool_members
                            .joins(:load_balancer_pool_member_pools => :load_balancer_pool)
                            .where(:load_balancer_pool_member_pools => {'load_balancer_pools' => {:ems_ref => manager_uuids}})
                            .distinct
      end

      attributes.merge!(extra_attributes)
    end

    def load_balancer_pool_member_pools(extra_attributes = {})
      attributes = {
        :model_class                  => ::LoadBalancerPoolMemberPool,
        :manager_ref                  => [:load_balancer_pool, :load_balancer_pool_member],
        :association                  => :load_balancer_pool_member_pools,
        :parent_inventory_collections => [:load_balancers]
      }

      extra_attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.load_balancer_pool_member_pools
                            .references(:load_balancer_pools)
                            .where(:load_balancer_pools => {:ems_ref => manager_uuids})
                            .distinct
      end

      attributes.merge!(extra_attributes)
    end

    def load_balancer_listeners(extra_attributes = {})
      attributes = {
        :model_class                  => ::LoadBalancerListener,
        :association                  => :load_balancer_listeners,
        :parent_inventory_collections => [:load_balancers],
        :use_ar_object                => true,
        :builder_params               => {
          :ems_id => ->(persister) { persister.manager.try(:network_manager).try(:id) || persister.manager.id },
        }
      }

      extra_attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.load_balancer_listeners.joins(:load_balancer).where(
          :load_balancers => {:ems_ref => manager_uuids}
        )
      end

      attributes.merge!(extra_attributes)
    end

    def load_balancer_listener_pools(extra_attributes = {})
      attributes = {
        :model_class                  => ::LoadBalancerListenerPool,
        :manager_ref                  => [:load_balancer_listener, :load_balancer_pool],
        :association                  => :load_balancer_listener_pools,
        :parent_inventory_collections => [:load_balancers]
      }

      extra_attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.load_balancer_listener_pools.joins(:load_balancer_pool).where(
          :load_balancer_pools => {:ems_ref => manager_uuids}
        )
      end

      attributes.merge!(extra_attributes)
    end

    def load_balancer_health_checks(extra_attributes = {})
      attributes = {
        :model_class                  => ::LoadBalancerHealthCheck,
        :association                  => :load_balancer_health_checks,
        :parent_inventory_collections => [:load_balancers],
        :builder_params               => {
          :ems_id => ->(persister) { persister.manager.try(:network_manager).try(:id) || persister.manager.id },
        }
      }

      extra_attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.load_balancer_health_checks.where(:ems_ref => manager_uuids)
      end

      attributes.merge!(extra_attributes)
    end

    def load_balancer_health_check_members(extra_attributes = {})
      attributes = {
        :model_class                  => ::LoadBalancerHealthCheckMember,
        :manager_ref                  => [:load_balancer_health_check, :load_balancer_pool_member],
        :association                  => :load_balancer_health_check_members,
        :parent_inventory_collections => [:load_balancers],
      }

      extra_attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
        inventory_collection.parent.load_balancer_health_check_members.references(:load_balancer_health_checks).where(
          :load_balancer_health_checks => {:ems_ref => manager_uuids}
        )
      end

      attributes.merge!(extra_attributes)
    end

    def network_groups(extra_attributes = {})
      attributes = {
        :model_class    => ::NetworkGroup,
        :association    => :network_groups,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.try(:network_manager).try(:id) || persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end
  end
end
