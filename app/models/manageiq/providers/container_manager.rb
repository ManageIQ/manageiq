module ManageIQ::Providers
  class ContainerManager < BaseManager
    include SupportsFeatureMixin

    has_many :container_nodes, -> { active }, # rubocop:disable Rails/HasManyOrHasOneDependent
             :foreign_key => :ems_id,
             :inverse_of  => :ext_management_system
    has_many :container_groups, -> { active }, # rubocop:disable Rails/HasManyOrHasOneDependent
             :foreign_key => :ems_id,
             :inverse_of  => :ext_management_system
    has_many :container_services, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_replicators, :foreign_key => :ems_id, :dependent => :destroy
    has_many :containers, -> { active }, # rubocop:disable Rails/HasManyOrHasOneDependent
             :foreign_key => :ems_id,
             :inverse_of  => :ext_management_system
    has_many :container_projects, -> { active }, # rubocop:disable Rails/HasManyOrHasOneDependent
             :foreign_key => :ems_id,
             :inverse_of  => :ext_management_system
    has_many :container_quotas, -> { active }, # rubocop:disable Rails/HasManyOrHasOneDependent
             :foreign_key => :ems_id,
             :inverse_of  => :ext_management_system
    has_many :container_routes, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_limits, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_image_registries, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_images, -> { active }, # rubocop:disable Rails/HasManyOrHasOneDependent
             :foreign_key => :ems_id,
             :inverse_of  => :ext_management_system
    has_many :persistent_volumes, :as => :parent, :dependent => :destroy
    has_many :persistent_volume_claims, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_builds, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_build_pods, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_templates, :foreign_key => :ems_id, :dependent => :destroy

    # Shortcuts to chained joins, mostly used by inventory refresh.
    has_many :computer_systems, :through => :container_nodes
    has_many :computer_system_hardwares, :through => :computer_systems, :source => :hardware
    has_many :computer_system_operating_systems, :through => :computer_systems, :source => :operating_system
    has_many :container_volumes, :through => :container_groups
    has_many :container_port_configs, :through => :containers
    has_many :container_env_vars, :through => :containers
    has_many :security_contexts, :through => :containers
    has_many :container_service_port_configs, :through => :container_services
    has_many :container_quota_scopes, :through => :container_quotas
    has_many :container_quota_items, :through => :container_quotas
    has_many :container_limit_items, :through => :container_limits
    has_many :container_template_parameters, :through => :container_templates
    has_many :computer_system_hardwares, :class_name => 'Hardware', :through => :computer_systems, :source => :hardware

    # Archived and active entities to destroy when the container manager is deleted
    has_many :all_containers, :foreign_key => :ems_id, :dependent => :destroy, :class_name => "Container"
    has_many :all_container_groups, :foreign_key => :ems_id, :dependent => :destroy, :class_name => "ContainerGroup"
    has_many :all_container_projects, :foreign_key => :ems_id, :dependent => :destroy, :class_name => "ContainerProject"
    has_many :all_container_images, :foreign_key => :ems_id, :dependent => :destroy, :class_name => "ContainerImage"
    has_many :all_container_nodes, :foreign_key => :ems_id, :dependent => :destroy, :class_name => "ContainerNode"
    has_many :all_container_quotas, :foreign_key => :ems_id, :dependent => :destroy, :class_name => "ContainerQuota"

    virtual_column :port_show, :type => :string
    virtual_sum    :aggregate_cpu_speed,       :computer_system_hardwares, :aggregate_cpu_speed
    virtual_sum    :aggregate_cpu_total_cores, :computer_system_hardwares, :cpu_total_cores
    virtual_sum    :aggregate_disk_capacity,   :computer_system_hardwares, :disk_capacity
    virtual_sum    :aggregate_memory,          :computer_system_hardwares, :memory_mb
    virtual_sum    :aggregate_physical_cpus,   :computer_system_hardwares, :cpu_sockets

    supports     :authentication_status
    supports     :metrics
    supports     :performance

    class << model_name
      define_method(:route_key) { "ems_containers" }
      define_method(:singular_route_key) { "ems_container" }
    end

    # enables overide of ChartsLayoutService#find_chart_path
    def chart_layout_path
      "ManageIQ_Providers_ContainerManager"
    end

    def port_show
      port.to_s
    end

    # this creates managers associated with this endpoint
    def endpoint_created(role)
      monitoring_endpoint_created(role) if respond_to?(:monitoring_endpoint_created)
      virtualization_endpoint_created(role) if respond_to?(:virtualization_endpoint_created)
    end

    # this destroys managers associated with this endpoint (via destroy_queue)
    def endpoint_destroyed(role)
      monitoring_endpoint_destroyed(role) if respond_to?(:monitoring_endpoint_destroyed)
      virtualization_endpoint_destroyed(role) if respond_to?(:virtualization_endpoint_destroyed)
    end
  end

  def self.display_name(number = 1)
    n_('Containers Manager', 'Containers Managers', number)
  end
end
