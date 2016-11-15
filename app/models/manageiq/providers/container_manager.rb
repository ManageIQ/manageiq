module ManageIQ::Providers
  class ContainerManager < BaseManager
    include AvailabilityMixin

    has_many :container_nodes, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_groups, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_services, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_replicators, :foreign_key => :ems_id, :dependent => :destroy
    has_many :containers, :foreign_key => :ems_id
    has_many :container_projects, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_quotas, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_limits, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_image_registries, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_images, :foreign_key => :ems_id, :dependent => :destroy
    has_many :persistent_volumes, :foreign_key => :parent_id, :dependent => :destroy
    has_many :persistent_volume_claims, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_component_statuses, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_builds, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_build_pods, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_templates, :foreign_key => :ems_id, :dependent => :destroy
    has_one :container_deployment, :foreign_key => :deployed_ems_id, :inverse_of => :deployed_ems

    virtual_column :port_show, :type => :string

    # required by aggregate_hardware
    def all_computer_system_ids
      MiqPreloader.preload(container_nodes, :computer_system)
      container_nodes.collect { |n| n.computer_system.id }
    end

    def aggregate_cpu_total_cores(targets = nil)
      aggregate_hardware(:computer_systems, :cpu_total_cores, targets)
    end

    def aggregate_memory(targets = nil)
      aggregate_hardware(:computer_systems, :memory_mb, targets)
    end

    class << model_name
      define_method(:route_key) { "ems_containers" }
      define_method(:singular_route_key) { "ems_container" }
    end

    # enables overide of ChartsLayoutService#find_chart_path
    def chart_layout_path
      "ManageIQ_Providers_ContainerManager"
    end

    def validate_performance
      {:available => true, :message => nil}
    end

    def validate_authentication_status
      {:available => true, :message => nil}
    end

    def port_show
      port.to_s
    end
  end
end
