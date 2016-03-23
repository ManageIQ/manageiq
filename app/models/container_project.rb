class ContainerProject < ApplicationRecord
  include CustomAttributeMixin
  include ReportableMixin
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :container_groups
  has_many :container_routes
  has_many :container_replicators
  has_many :container_services
  has_many :container_definitions, :through => :container_groups
  has_many :container_nodes, -> { distinct }, :through => :container_groups
  has_many :container_quotas
  has_many :container_quota_items, :through => :container_quotas
  has_many :container_limits
  has_many :container_limit_items, :through => :container_limits
  has_many :container_builds

  # Needed for metrics
  has_many :metrics,                :as => :resource
  has_many :metric_rollups,         :as => :resource
  has_many :vim_performance_states, :as => :resource
  delegate :my_zone,                :to => :ext_management_system

  has_many :labels, -> { where(:section => "labels") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy

  virtual_column :groups_count,      :type => :integer
  virtual_column :services_count,    :type => :integer
  virtual_column :routes_count,      :type => :integer
  virtual_column :replicators_count, :type => :integer
  virtual_column :containers_count,  :type => :integer

  def groups_count
    container_groups.size
  end

  def routes_count
    container_routes.size
  end

  def replicators_count
    container_replicators.size
  end

  def services_count
    container_services.size
  end

  def containers_count
    container_definitions.size
  end

  include EventMixin
  include Metric::CiMixin

  PERF_ROLLUP_CHILDREN = :container_groups

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

  def disconnect_inv
    _log.info "Disconnecting Container Project [#{name}] id [#{id}] from EMS [#{ext_management_system.name}]" \
    "id [#{ext_management_system.id}] "
    self.old_ems_id = ems_id
    self.ext_management_system = nil
    self.deleted_on = Time.now.utc
    save
  end
end
