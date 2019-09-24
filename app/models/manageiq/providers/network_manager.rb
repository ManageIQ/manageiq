module ManageIQ::Providers
  class NetworkManager < BaseManager
    include SupportsFeatureMixin

    PROVIDER_NAME = "Network Manager".freeze

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

    # Uses "ext_management_systems"."parent_ems_id" instead of "ext_management_systems"."id"
    #
    # ORDER BY ((
    #   SELECT COUNT(*)
    #   FROM "vms"
    #   WHERE "ext_management_systems"."parent_ems_id" = "vms"."ems_id"
    # ))
    #
    # So unlike the parent class definition, this looks at "ext_management_systems"."parent_ems_id" instead of
    # "ext_management_systems"."id"
    # If we are able to define a has_many :vms, :through => :parent_manager, that does actual join, this code should
    # not be needed.
    virtual_total :total_vms, :vms, {
      :arel => lambda do |t|
        foreign_table = Vm.arel_table
        local_key     = :parent_ems_id
        foreign_key   = :ems_id
        arel_column   = Arel.star.count
        t.grouping(foreign_table.project(arel_column).where(t[local_key].eq(foreign_table[foreign_key])))
      end
    }

    alias all_cloud_networks cloud_networks

    belongs_to :parent_manager,
               :foreign_key => :parent_ems_id,
               :class_name  => "ManageIQ::Providers::BaseManager",
               :autosave    => true

    has_many :availability_zones, -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id

    # Relationships delegated to parent manager
    delegate :cloud_tenants,
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
             :vms_and_templates,
             :total_vms_and_templates,
             :miq_templates,
             :total_miq_templates,
             :hosts,
             :to        => :parent_manager,
             :allow_nil => true

    def self.supported_types_and_descriptions_hash
      supported_subclasses.select(&:supports_ems_network_new?).each_with_object({}) do |klass, hash|
        if Vmdb::PermissionStores.instance.supported_ems_type?(klass.ems_type)
          hash[klass.ems_type] = klass.description
        end
      end
    end

    def name
      "#{parent_manager.try(:name)} #{PROVIDER_NAME}"
    end

    def self.find_object_for_belongs_to_filter(name)
      name.gsub!(" #{self::PROVIDER_NAME}", "")
      includes(:parent_manager).find_by(:parent_managers_ext_management_systems => {:name => name})
    end
  end

  def self.display_name(number = 1)
    n_('Network Manager', 'Network Managers', number)
  end
end
