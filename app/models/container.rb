class Container < ApplicationRecord
  include ReportableMixin
  include NewWithTypeStiMixin

  has_one    :container_group, :through => :container_definition
  has_one    :ext_management_system, :through => :container_group
  has_one    :container_node, :through => :container_group
  has_one    :container_replicator, :through => :container_group
  has_one    :container_project, :through => :container_group
  belongs_to :container_definition
  belongs_to :container_image
  has_one    :container_image_registry, :through => :container_image
  has_one    :security_context, :through => :container_definition

  # Metrics destroy are handled by the purger
  has_many   :metrics, :as => :resource
  has_many   :metric_rollups, :as => :resource
  has_many   :vim_performance_states, :as => :resource

  # Needed for metrics
  delegate   :ems_id, :to => :container_group
  delegate   :my_zone, :to => :ext_management_system

  include EventMixin
  include Metric::CiMixin

  acts_as_miq_taggable

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events
      # TODO: improve relationship using the id
      ["container_namespace = ? AND #{events_table_name(assoc)}.ems_id = ? AND container_name = ?",
       container_project.name, ext_management_system.id, name]
    when :policy_events
      # TODO: implement policy events and its relationship
      ["#{events_table_name(assoc)}.ems_id = ?", ext_management_system.id]
    end
  end

  PERF_ROLLUP_CHILDREN = nil

  def perf_rollup_parents(_interval_name = nil)
    # No rollups: nodes performance are collected separately
  end
end
