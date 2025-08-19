class ContainerGroup < ApplicationRecord
  acts_as_miq_taggable

  include SupportsFeatureMixin
  include ComplianceMixin
  include CustomAttributeMixin
  include MiqPolicyMixin
  include NewWithTypeStiMixin
  include TenantIdentityMixin
  include ArchivedMixin
  include CustomActionsMixin
  include Purging

  # :name, :uid, :creation_timestamp, :resource_version, :namespace
  # :labels, :restart_policy, :dns_policy

  has_many :containers, :dependent => :destroy
  has_many :running_containers, -> { where(:state => "running") }, :class_name => "Container", :inverse_of => :container_group # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :container_images, -> { distinct }, :through => :containers, :inverse_of => :container_group
  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many :annotations, -> { where(:section => "annotations") }, # rubocop:disable Rails/HasManyOrHasOneDependent
           :class_name => "CustomAttribute",
           :as         => :resource,
           :inverse_of => :resource
  has_many :labels, -> { where(:section => "labels") }, # rubocop:disable Rails/HasManyOrHasOneDependent
           :class_name => "CustomAttribute",
           :as         => :resource,
           :inverse_of => :resource
  has_many :node_selector_parts, -> { where(:section => "node_selectors") }, # rubocop:disable Rails/HasManyOrHasOneDependent
           :class_name => "CustomAttribute",
           :as         => :resource,
           :inverse_of => :resource
  has_many :container_conditions, :class_name => "ContainerCondition", :as => :container_entity, :dependent => :destroy
  has_one  :ready_condition, -> { where(:name => "Ready") }, :class_name => "ContainerCondition", :as => :container_entity, :inverse_of => :container_entity # rubocop:disable Rails/HasManyOrHasOneDependent
  belongs_to :container_node
  has_and_belongs_to_many :container_services, :join_table => :container_groups_container_services
  belongs_to :container_replicator
  belongs_to :container_project
  belongs_to :container_build_pod
  has_many :container_volumes, :as => :parent, :dependent => :destroy
  has_many :persistent_volume_claim, :through => :container_volumes
  has_many :persistent_volumes, -> { where(:type=>'PersistentVolume') }, :through => :persistent_volume_claim, :source => :container_volumes

  # Metrics destroy is handled by purger
  has_many :metrics, :as => :resource
  has_many :metric_rollups, :as => :resource
  has_many :vim_performance_states, :as => :resource
  delegate :my_zone, :to => :ext_management_system, :allow_nil => true

  virtual_delegate :status, :prefix => true, :to => :ready_condition, :allow_nil => true, :default => "None", :type => :string
  virtual_attribute :running_containers_summary, :integer, :arel => (lambda do |t|
    t.grouping(Arel::Nodes::NamedFunction.new('CONCAT', [t[:total_running_containers], Arel.sql("'/'"), t[:total_containers]]))
  end)

  virtual_total  :total_containers, :containers
  virtual_total  :total_running_containers, :running_containers

  # validates :restart_policy, :inclusion => { :in => %w(always onFailure never) }
  # validates :dns_policy, :inclusion => { :in => %w(ClusterFirst Default) }

  include EventMixin
  include Metric::CiMixin

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

  def ems_event_filter
    {
      "container_group_name" => name,
      "container_namespace"  => container_project.name,
      "ems_id"               => ext_management_system.id
    }
  end

  def miq_event_filter
    {"ems_id" => ext_management_system.id}
  end

  PERF_ROLLUP_CHILDREN = []

  def perf_rollup_parents(interval_name = nil)
    unless interval_name == 'realtime'
      ([container_project, container_replicator] + container_services).compact
    end
  end

  def disconnect_inv
    return if archived?

    _log.info("Disconnecting Pod [#{name}] id [#{id}] from EMS [#{ext_management_system.name}] id [#{ext_management_system.id}]")
    containers.each(&:disconnect_inv)
    self.container_services = []
    self.container_replicator_id = nil
    self.container_build_pod_id = nil
    self.deleted_on = Time.now.utc
    save
  end

  def self.display_name(number = 1)
    n_('Pod', 'Pods', number)
  end
end
