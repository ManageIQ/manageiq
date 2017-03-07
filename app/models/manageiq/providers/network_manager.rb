module ManageIQ::Providers
  class NetworkManager < BaseManager
    include SupportsFeatureMixin
    class << model_name
      define_method(:route_key) { "ems_networks" }
      define_method(:singular_route_key) { "ems_network" }
    end

    supports_not :ems_network_new
    # cloud_subnets are defined on base class, because of virtual_total performance
    has_many :floating_ips,                :foreign_key => :ems_id, :dependent => :destroy
    has_many :security_groups,             :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_networks,              :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_ports,               :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_routers,             :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_groups,              :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancers,              :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_pools,         :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_pool_members,  :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_listeners,     :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_health_checks, :foreign_key => :ems_id, :dependent => :destroy

    alias all_cloud_networks cloud_networks

    belongs_to :parent_manager,
               :foreign_key => :parent_ems_id,
               :class_name  => "ManageIQ::Providers::BaseManager",
               :autosave    => true

    # Relationships delegated to parent manager
    delegate :availability_zones,
             :cloud_tenants,
             :flavors,
             :cloud_resource_quotas,
             :cloud_volumes,
             :cloud_volume_snapshots,
             :cloud_object_store_containers,
             :cloud_object_store_objects,
             :key_pairs,
             :orchestration_stacks,
             :orchestration_stacks_resources,
             :direct_orchestration_stacks,
             :resource_groups,
             :vms,
             :total_vms,
             :hosts,
             :to        => :parent_manager,
             :allow_nil => true

    def validate_timeline
      {:available => true, :message => nil}
    end

    def self.supported_types_and_descriptions_hash
      supported_subclasses.select(&:supports_ems_network_new?).each_with_object({}) do |klass, hash|
        if Vmdb::PermissionStores.instance.supported_ems_type?(klass.ems_type)
          hash[klass.ems_type] = klass.description
        end
      end
    end
  end
end
