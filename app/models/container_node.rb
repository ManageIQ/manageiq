class ContainerNode < ApplicationRecord
  acts_as_miq_taggable

  include SupportsFeatureMixin
  include ComplianceMixin
  include MiqPolicyMixin
  include NewWithTypeStiMixin
  include TenantIdentityMixin
  include SupportsFeatureMixin
  include ArchivedMixin
  include CustomActionsMixin
  include Purging

  EXTERNAL_LOGGING_PATH = "/#/discover?_g=()&_a=(columns:!(hostname,level,kubernetes.pod_name,message),filters:!((meta:(disabled:!f,index:'%{index}',key:hostname,negate:!f),%{query})),index:'%{index}',interval:auto,query:(query_string:(analyze_wildcard:!t,query:'*')),sort:!(time,desc))".freeze

  # :name, :uid, :creation_timestamp, :resource_version
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many   :container_groups, -> { active }
  has_many   :container_conditions, :class_name => "ContainerCondition", :as => :container_entity, :dependent => :destroy
  has_one    :ready_condition, -> { where(:name => "Ready") }, :class_name => "ContainerCondition", :as => :container_entity, :inverse_of => :container_entity # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many   :containers, :through => :container_groups
  has_many   :container_images, -> { distinct }, :through => :container_groups
  has_many   :container_services, -> { distinct }, :through => :container_groups
  has_many   :container_routes, -> { distinct }, :through => :container_services
  has_many   :container_replicators, -> { distinct }, :through => :container_groups
  has_many   :labels, -> { where(:section => "labels") }, # rubocop:disable Rails/HasManyOrHasOneDependent
             :class_name => "CustomAttribute",
             :as         => :resource,
             :inverse_of => :resource
  has_many   :additional_attributes, -> { where(:section => "additional_attributes") }, # rubocop:disable Rails/HasManyOrHasOneDependent
             :class_name => "CustomAttribute",
             :as         => :resource,
             :inverse_of => :resource
  has_one    :computer_system, :as => :managed_entity, :dependent => :destroy
  belongs_to :lives_on, :polymorphic => true
  has_one    :hardware, :through => :computer_system
  has_one    :operating_system, :through => :computer_system

  # Metrics destroy is handled by purger
  has_many :metrics, :as => :resource
  has_many :metric_rollups, :as => :resource
  has_many :vim_performance_states, :as => :resource
  has_many :miq_alert_statuses, :as => :resource
  delegate :my_zone, :to => :ext_management_system, :allow_nil => true

  virtual_column :ready_condition_status, :type => :string, :uses => :container_conditions
  virtual_delegate :system_distribution, :to => "operating_system.distribution", :allow_nil => true, :type => :string
  virtual_delegate :kernel_version, :to => :operating_system, :allow_nil => true, :type => :string

  def ready_condition_status
    ready_condition.try(:status) || 'None'
  end

  include EventMixin
  include Metric::CiMixin
  include CustomAttributeMixin

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events, :event_streams
      # TODO: improve relationship using the id
      ["container_node_name = ? AND #{events_table_name(assoc)}.ems_id = ?", name, ems_id]
    when :policy_events
      # TODO: implement policy events and its relationship
      ["#{events_table_name(assoc)}.ems_id = ?", ems_id]
    end
  end

  def ems_event_filter
    {
      "container_node_name" => name,
      "ems_id"              => ext_management_system.id
    }
  end

  def miq_event_filter
    {"ems_id" => ext_management_system.id}
  end

  # TODO: children will be container groups
  PERF_ROLLUP_CHILDREN = []

  def perf_rollup_parents(interval_name = nil)
    [ext_management_system] unless interval_name == 'realtime'
  end

  def kubernetes_hostname
    labels.find_by(:name => "kubernetes.io/hostname").try(:value)
  end

  def evaluate_alert(_alert_id, _event)
    # This is a no-op on container node, and used to be implemented only for
    # Hawkular-generated EmsEvents.
    true
  end

  def external_logging_query
    nil # {}.to_query # TODO
  end

  def external_logging_path
    node_hostnames = [kubernetes_hostname || name] # node name cannot be empty, it's an ID
    node_hostnames.push(node_hostnames.first.split('.').first).compact!
    node_hostnames_query = node_hostnames.uniq.map { |x| "(term:(hostname:'#{x}'))" }.join(",")
    query = "bool:(filter:(or:!(#{node_hostnames_query})))"
    index = ".operations.*"
    EXTERNAL_LOGGING_PATH % {:index => index, :query => query}
  end

  def disconnect_inv
    return if archived?

    _log.info("Disconnecting Node [#{name}] id [#{id}] from EMS [#{ext_management_system.name}]" \
    "id [#{ext_management_system.id}] ")
    self.deleted_on = Time.now.utc
    save
  end
end
