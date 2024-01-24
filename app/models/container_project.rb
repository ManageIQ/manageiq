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
  has_many :container_routes
  has_many :container_replicators
  has_many :container_services
  has_many :containers, :through => :container_groups
  has_many :container_images, -> { distinct }, :through => :container_groups
  has_many :container_nodes, -> { distinct }, :through => :container_groups
  has_many :container_quotas, -> { active }, :inverse_of => :container_project
  has_many :container_quota_scopes, :through => :container_quotas
  has_many :container_quota_items, :through => :container_quotas
  has_many :container_limits
  has_many :container_limit_items, :through => :container_limits
  has_many :container_builds
  has_many :container_templates
  has_many :all_container_groups, :class_name => "ContainerGroup", :inverse_of => :container_project
  has_many :archived_container_groups, -> { archived }, :class_name => "ContainerGroup"
  has_many :persistent_volume_claims
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
end
