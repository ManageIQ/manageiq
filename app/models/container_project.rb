class ContainerProject < ApplicationRecord
  acts_as_miq_taggable

  include SupportsFeatureMixin
  include CustomAttributeMixin
  include ArchivedMixin
  include MiqPolicyMixin
  include TenantIdentityMixin
  include CustomActionsMixin
  include Purging
  belongs_to :ext_management_system, :class_name => "ManageIQ::Providers::ContainerManager", :foreign_key => "ems_id", :inverse_of => :container_projects
  has_many :container_groups, -> { active }, :inverse_of => :container_project
  has_many :container_routes      # delete to be handled by refresh
  has_many :container_replicators # delete to be handled by refresh
  has_many :container_services    # delete to be handled by refresh
  has_many :containers, :through => :container_groups
  has_many :container_images, -> { distinct }, :through => :container_groups
  has_many :container_nodes, -> { distinct }, :through => :container_groups
  has_many :container_quotas, -> { active }, :inverse_of => :container_project
  has_many :container_quota_scopes, :through => :container_quotas
  has_many :container_quota_items, :through => :container_quotas
  has_many :container_limits      # delete to be handled by refresh
  has_many :container_limit_items, :through => :container_limits
  has_many :container_builds      # delete to be handled by refresh
  has_many :container_templates   # delete to be handled by refresh
  has_many :all_container_groups, :class_name => "ContainerGroup", :inverse_of => :container_project
  has_many :archived_container_groups, -> { archived }, :class_name => "ContainerGroup"
  has_many :persistent_volume_claims # claims are removed by the container_volume when it's removed
  has_many :miq_alert_statuses, :as => :resource, :dependent => :destroy
  has_many :computer_systems, :through => :container_nodes

  # Needed for metrics
  has_many :metrics,                :as => :resource
  has_many :metric_rollups,         :as => :resource
  has_many :vim_performance_states, :as => :resource

  has_many :labels, -> { where(:section => "labels") }, # rubocop:disable Rails/HasManyOrHasOneDependent
           :class_name => "CustomAttribute",
           :as         => :resource,
           :inverse_of => :resource

  virtual_total :groups_count,      :container_groups
  virtual_total :services_count,    :container_services
  virtual_total :routes_count,      :container_routes
  virtual_total :replicators_count, :container_replicators
  virtual_total :containers_count,  :containers
  virtual_total :images_count,      :container_images

  after_create :raise_creation_event

  include EventMixin
  include Metric::CiMixin

  PERF_ROLLUP_CHILDREN = [:all_container_groups].freeze

  delegate :my_zone, :to => :ext_management_system, :allow_nil => true

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events, :event_streams
      # TODO: improve relationship using the id
      ["container_namespace = ? AND #{events_table_name(assoc)}.ems_id = ?", name, ems_id]
    when :policy_events
      # TODO: implement policy events and its relationship
      ["ems_id = ?", ems_id]
    end
  end

  def ems_event_filter
    {
      "container_namespace" => name,
      "ems_id"              => ext_management_system.id
    }
  end

  def miq_event_filter
    {"ems_id" => ext_management_system.id}
  end

  def perf_rollup_parents(_interval_name = nil)
    []
  end

  def aggregate_memory(_targets = nil)
    Hardware.where(:computer_system => computer_systems).sum(:memory_mb)
  end

  def aggregate_cpu_speed(_targets = nil)
    Hardware.where(:computer_system => computer_systems).sum(:cpu_speed)
  end

  def aggregate_cpu_total_cores(_targets = nil)
    Hardware.where(:computer_system => computer_systems).sum(:cpu_total_cores)
  end

  def disconnect_inv
    return if archived?

    _log.info("Disconnecting Container Project [#{name}] id [#{id}] from EMS [#{ext_management_system.name}] id [#{ext_management_system.id}]")
    self.deleted_on = Time.now.utc
    save
  end

  def self.raise_creation_events(container_project_ids)
    where(:id => container_project_ids).find_each do |record|
      MiqEvent.raise_evm_event(record, 'containerproject_created', {})
    end
  end

  def raise_creation_event
    MiqEvent.raise_evm_event(self, 'containerproject_created', {})
  end

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:ContainerProject)
  end

  def self.create_container_project(ems_id, options = {})
    ems = ExtManagementSystem.find_by(:id => ems_id)
    raise ArgumentError, _("EMS cannot be nil") if ems.nil?

    klass = ems.class_by_ems(:ContainerProject)
    klass.raw_create_container_project(ems, options)
  end

  def self.raw_create_container_project(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_create_container_project must be implemented in a subclass")
  end

  def self.create_container_project_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "Creating Container Project for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => ext_management_system.class_by_ems(:ContainerProject).name,
      :method_name => 'create_container_project',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_container_project(options = {})
    raw_update_container_project(options)
  end

  def raw_update_container_project(_options = {})
    raise NotImplementedError, _("raw_update_container_project must be implemented in a subclass")
  end

  def update_container_project_queue(userid, options = {})
    task_opts = {
      :action => "Updating Container Project for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_container_project',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_container_project
    raw_delete_container_project
  end

  def delete_container_project_queue(userid)
    task_opts = {
      :action => "Deleting Container Project for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_container_project',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_delete_container_project
    raise NotImplementedError, _("raw_delete_container_project must be implemented in a subclass")
  end
end
