class ContainerReplicator < ApplicationRecord
  acts_as_miq_taggable

  include SupportsFeatureMixin
  include ComplianceMixin
  include CustomAttributeMixin
  include MiqPolicyMixin
  include TenantIdentityMixin

  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many :container_groups
  belongs_to :container_project
  has_many :labels, -> { where(:section => "labels") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy
  has_many :selector_parts, -> { where(:section => "selectors") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy
  has_many :container_nodes, -> { distinct }, :through => :container_groups

  # Needed for metrics
  has_many :metrics,                :as => :resource
  has_many :metric_rollups,         :as => :resource
  has_many :vim_performance_states, :as => :resource
  delegate :my_zone,                :to => :ext_management_system

  include EventMixin
  include Metric::CiMixin

  PERF_ROLLUP_CHILDREN = [:container_groups]

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events, :event_streams
      # TODO: improve relationship using the id
      ["container_namespace = ? AND container_replicator_name = ? AND #{events_table_name(assoc)}.ems_id = ?",
       container_project.name, name, ems_id]
    when :policy_events
      # TODO: implement policy events and its relationship
      ["#{events_table_name(assoc)}.ems_id = ?", ems_id]
    end
  end

  def perf_rollup_parents(interval_name = nil)
    []
  end
end
