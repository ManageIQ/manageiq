module ManageIQ::Providers
  class NetworkManager < BaseManager
    include SupportsFeatureMixin
    class << model_name
      define_method(:route_key) { "ems_networks" }
      define_method(:singular_route_key) { "ems_network" }
    end

    supports_not :ems_network_new
    # cloud_subnets are defined on base class, because of virtual_total performance
    has_many :floating_ips,                       :foreign_key => :ems_id, :dependent => :destroy
    has_many :security_groups,                    :foreign_key => :ems_id, :dependent => :destroy
    has_many :firewall_rules,                     :through => :security_groups
    has_many :cloud_networks,                     :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_ports,                      :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_subnet_network_ports,         :through => :network_ports
    has_many :network_routers,                    :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_groups,                     :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancers,                     :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_pools,                :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_pool_member_pools,    :through => :load_balancer_pools
    has_many :load_balancer_pool_members,         :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_listeners,            :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_listener_pools,       :through => :load_balancer_listeners
    has_many :load_balancer_health_checks,        :foreign_key => :ems_id, :dependent => :destroy
    has_many :load_balancer_health_check_members, :through => :load_balancer_health_checks

    # Relations using a parent manager
    has_many :availability_zones,             -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_tenants,                  -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :flavors,                        -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_resource_quotas,          -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :key_pairs,                      -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id,
             :class_name  => "AuthPrivateKey"
    has_many :orchestration_stacks,           -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :orchestration_stacks_resources, -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :direct_orchestration_stacks,    -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :resource_groups,                -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :vms,                            -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :hosts,                          -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id

    virtual_total :total_vms, :vms

    alias all_cloud_networks cloud_networks

    belongs_to :parent_manager,
               :foreign_key => :parent_ems_id,
               :class_name  => "ManageIQ::Providers::BaseManager",
               :autosave    => true

    # We cannot us a has many using :parent_ems_id primary key, since this doesn't belong to parent manager, so we need
    # proper has_many :through or to delete these delegations.
    delegate :cloud_volumes,
             :cloud_volume_snapshots,
             :cloud_object_store_containers,
             :cloud_object_store_objects,
             :to        => :parent_manager,
             :allow_nil => true

    def self.supported_types_and_descriptions_hash
      supported_subclasses.select(&:supports_ems_network_new?).each_with_object({}) do |klass, hash|
        if Vmdb::PermissionStores.instance.supported_ems_type?(klass.ems_type)
          hash[klass.ems_type] = klass.description
        end
      end
    end
  end
end
