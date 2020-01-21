class ContainerProject < ApplicationRecord
  include SupportsFeatureMixin
  include CustomAttributeMixin
  include ArchivedMixin
  include MiqPolicyMixin
  include TenantIdentityMixin
  include CustomActionsMixin
  include_concern 'Purging'
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :container_groups, -> { active }
  has_many :container_routes
  has_many :container_replicators
  has_many :container_services
  has_many :containers, :through => :container_groups
  has_many :container_images, -> { distinct }, :through => :container_groups
  has_many :container_nodes, -> { distinct }, :through => :container_groups
  has_many :container_quotas, -> { active }
  has_many :container_quota_scopes, :through => :container_quotas
  has_many :container_quota_items, :through => :container_quotas
  has_many :container_limits
  has_many :container_limit_items, :through => :container_limits
  has_many :container_builds
  has_many :container_templates
  has_many :archived_container_groups, :foreign_key => "old_container_project_id", :class_name => "ContainerGroup"
  has_many :persistent_volume_claims
  has_many :miq_alert_statuses, :as => :resource, :dependent => :destroy
  has_many :computer_systems, :through => :container_nodes

  # Needed for metrics
  has_many :metrics,                :as => :resource
  has_many :metric_rollups,         :as => :resource
  has_many :vim_performance_states, :as => :resource

  has_many :labels, -> { where(:section => "labels") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy

  virtual_total :groups_count,      :container_groups
  virtual_total :services_count,    :container_services
  virtual_total :routes_count,      :container_routes
  virtual_total :replicators_count, :container_replicators
  virtual_total :containers_count,  :containers
  virtual_total :images_count,      :container_images

  after_create :raise_creation_event

  include EventMixin
  include Metric::CiMixin
  include AggregationMixin::Methods

  PERF_ROLLUP_CHILDREN = :all_container_groups

  delegate :my_zone, :to => :ext_management_system, :allow_nil => true

  def all_container_groups
    ContainerGroup.where(:container_project_id => id).or(ContainerGroup.where(:old_container_project_id => id))
  end

  acts_as_miq_taggable

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

  def perf_rollup_parents(interval_name = nil)
    []
  end

  # required by aggregate_hardware
  alias all_computer_system_ids computer_system_ids

  def aggregate_memory(targets = nil)
    aggregate_hardware(:computer_systems, :memory_mb, targets)
  end

  def aggregate_cpu_speed(targets = nil)
    aggregate_hardware(:computer_systems, :cpu_speed, targets)
  end

  def aggregate_cpu_total_cores(targets = nil)
    aggregate_hardware(:computer_systems, :cpu_total_cores, targets)
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
