module ManageIQ::Providers
  class Inventory::Persister
    class Builder
      class NetworkManager < ::ManageIQ::Providers::Inventory::Persister::Builder
        def cloud_subnet_network_ports
          add_properties(
            # :model_class                  => ::CloudSubnetNetworkPort,
            :manager_ref                  => %i(address cloud_subnet network_port),
            :parent_inventory_collections => %i(vms network_ports load_balancers)
          )

          add_targeted_arel(
            lambda do |inventory_collection|
              manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
              inventory_collection.parent.cloud_subnet_network_ports.references(:network_ports).where(
                :network_ports => {:ems_ref => manager_uuids}
              )
            end
          )
        end

        def network_ports
          add_properties(
            :use_ar_object  => true,
            # TODO(lsmola) can't do batch strategy for network_ports because of security_groups relation
            :saver_strategy => :default
          )

          add_common_default_values
        end

        def network_groups
          add_common_default_values
        end

        def network_routers
          add_common_default_values
        end

        def floating_ips
          add_common_default_values
        end

        def cloud_tenants
          add_common_default_values
        end

        def cloud_subnets
          add_common_default_values
        end

        def cloud_networks
          add_common_default_values
        end

        def security_groups
          add_common_default_values
        end

        def firewall_rules
          add_properties(
            :manager_ref                  => %i(resource source_security_group direction host_protocol port end_port source_ip_range),
            :parent_inventory_collections => %i(security_groups)
          )
        end

        def load_balancers
          add_common_default_values
        end

        def load_balancer_pools
          add_properties(
            :parent_inventory_collections => %i(load_balancers)
          )

          add_targeted_arel(
            lambda do |inventory_collection|
              manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
              inventory_collection.parent.load_balancer_pools
                .joins(:load_balancers)
                .where(:load_balancers => {:ems_ref => manager_uuids})
                .distinct
            end
          )

          add_common_default_values
        end

        def load_balancer_pool_members
          add_properties(
            :parent_inventory_collections => %i(load_balancers)
          )

          add_targeted_arel(
            lambda do |inventory_collection|
              manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
              inventory_collection.parent.load_balancer_pool_members
                .joins(:load_balancer_pool_member_pools => [:load_balancer_pool => :load_balancers])
                .where(:load_balancer_pool_member_pools => {
                         'load_balancer_pools' => {
                           'load_balancers' => {
                             :ems_ref => manager_uuids
                           }
                         }
                       }).distinct
            end
          )

          add_common_default_values
        end

        def load_balancer_pool_member_pools
          add_properties(
            :manager_ref                  => %i(load_balancer_pool load_balancer_pool_member),
            :parent_inventory_collections => %i(load_balancers)
          )

          add_targeted_arel(
            lambda do |inventory_collection|
              manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
              inventory_collection.parent.load_balancer_pool_member_pools
                .joins(:load_balancer_pool => :load_balancers)
                .where(:load_balancer_pools => { 'load_balancers' => { :ems_ref => manager_uuids } })
                .distinct
            end
          )
        end

        def load_balancer_listeners
          add_properties(
            :use_ar_object                => true,
            :parent_inventory_collections => %i(load_balancers),
          )

          add_targeted_arel(
            lambda do |inventory_collection|
              manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
              inventory_collection.parent.load_balancer_listeners
                .joins(:load_balancer)
                .where(:load_balancers => {:ems_ref => manager_uuids})
                .distinct
            end
          )

          add_common_default_values
        end

        def load_balancer_listener_pools
          add_properties(
            :manager_ref                  => %i(load_balancer_listener load_balancer_pool),
            :parent_inventory_collections => %i(load_balancers)
          )

          add_targeted_arel(
            lambda do |inventory_collection|
              manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
              inventory_collection.parent.load_balancer_listener_pools
                .joins(:load_balancer_pool => :load_balancers)
                .where(:load_balancer_pools => {'load_balancers' => {:ems_ref => manager_uuids}})
                .distinct
            end
          )
        end

        def load_balancer_health_checks
          add_properties(
            :parent_inventory_collections => %i(load_balancers)
          )

          add_targeted_arel(
            lambda do |inventory_collection|
              manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
              inventory_collection.parent.load_balancer_health_checks
                .joins(:load_balancer)
                .where(:load_balancers => {:ems_ref => manager_uuids})
                .distinct
            end
          )

          add_common_default_values
        end

        def load_balancer_health_check_members
          add_properties(
            :manager_ref                  => %i(load_balancer_health_check load_balancer_pool_member),
            :parent_inventory_collections => %i(load_balancers)
          )

          add_targeted_arel(
            lambda do |inventory_collection|
              manager_uuids = inventory_collection.parent_inventory_collections.flat_map { |c| c.manager_uuids.to_a }
              inventory_collection.parent.load_balancer_health_check_members
                .joins(:load_balancer_health_check => :load_balancer)
                .where(:load_balancer_health_checks => {'load_balancers' => {:ems_ref => manager_uuids}})
                .distinct
            end
          )
        end

        protected

        def add_common_default_values
          add_default_values(:ems_id => default_ems_id)
        end

        def default_ems_id
          ->(persister) { persister.manager.try(:network_manager).try(:id) || persister.manager.id }
        end
      end
    end
  end
end
