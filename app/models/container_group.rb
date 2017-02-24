class ContainerGroup < ApplicationRecord
  include ComplianceMixin
  include CustomAttributeMixin
  include MiqPolicyMixin
  include NewWithTypeStiMixin
  include TenantIdentityMixin
  include ArchivedMixin

  # :name, :uid, :creation_timestamp, :resource_version, :namespace
  # :labels, :restart_policy, :dns_policy

  has_many :containers,
           :through => :container_definitions
  has_many :container_definitions, :dependent => :destroy
  has_many :container_images, -> { distinct }, :through => :container_definitions
  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many :labels, -> { where(:section => "labels") }, :class_name => CustomAttribute, :as => :resource, :dependent => :destroy
  has_many :node_selector_parts, -> { where(:section => "node_selectors") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy
  has_many :container_conditions, :class_name => ContainerCondition, :as => :container_entity, :dependent => :destroy
  belongs_to :container_node
  has_and_belongs_to_many :container_services, :join_table => :container_groups_container_services
  belongs_to :container_replicator
  belongs_to :container_project
  belongs_to :old_container_project, :foreign_key => "old_container_project_id", :class_name => 'ContainerProject'
  belongs_to :container_build_pod
  has_many :container_volumes, :foreign_key => :parent_id, :dependent => :destroy

  # Metrics destroy is handled by purger
  has_many :metrics, :as => :resource
  has_many :metric_rollups, :as => :resource
  has_many :vim_performance_states, :as => :resource

  virtual_column :ready_condition_status, :type => :string, :uses => :container_conditions
  virtual_column :running_containers_summary, :type => :string

  def ready_condition
    container_conditions.find_by(:name => "Ready")
  end

  def ready_condition_status
    ready_condition.try(:status) || 'None'
  end

  def container_states_summary
    containers.group(:state).count.symbolize_keys
  end

  def running_containers_summary
    summary = container_states_summary
    "#{summary[:running] || 0}/#{summary.values.sum}"
  end

  # validates :restart_policy, :inclusion => { :in => %w(always onFailure never) }
  # validates :dns_policy, :inclusion => { :in => %w(ClusterFirst Default) }

  include EventMixin
  include Metric::CiMixin

  acts_as_miq_taggable

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events, :event_streams
      # TODO: improve relationship using the id
      ["container_namespace = ? AND container_group_name = ? AND #{events_table_name(assoc)}.ems_id = ?",
       container_project.try(:name), name, ems_id]
    when :policy_events
      # TODO: implement policy events and its relationship
      ["#{events_table_name(assoc)}.ems_id = ?", ems_id]
    end
  end

  PERF_ROLLUP_CHILDREN = nil

  def perf_rollup_parents(interval_name = nil)
    unless interval_name == 'realtime'
      ([container_project, container_replicator] + container_services).compact
    end
  end

  def disconnect_inv
    _log.info "Disconnecting Pod [#{name}] id [#{id}] from EMS [#{ext_management_system.name}]" \
    "id [#{ext_management_system.id}] "
    self.container_definitions.each(&:disconnect_inv)
    self.old_ems_id = ems_id
    self.ext_management_system = nil
    self.container_node_id = nil
    self.container_services = []
    self.container_replicator_id = nil
    self.container_build_pod_id = nil
    self.old_container_project_id = self.container_project_id
    self.container_project_id = nil
    self.deleted_on = Time.now.utc
    save
  end
end
