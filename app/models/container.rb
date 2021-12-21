class Container < ApplicationRecord
  include SupportsFeatureMixin
  include NewWithTypeStiMixin
  include ArchivedMixin
  include_concern 'Purging'

  belongs_to :container_group
  belongs_to :ext_management_system, :foreign_key => :ems_id
  has_one    :container_node, :through => :container_group
  has_one    :container_replicator, :through => :container_group
  has_one    :container_project, :through => :container_group
  has_one    :old_container_project, :through => :container_group
  belongs_to :container_image
  has_many   :container_port_configs, :dependent => :destroy
  has_many   :container_env_vars, :dependent => :destroy
  has_one    :container_image_registry, :through => :container_image
  has_one    :security_context, :as => :resource, :dependent => :destroy

  # Metrics destroy are handled by the purger
  has_many   :metrics, :as => :resource
  has_many   :metric_rollups, :as => :resource
  has_many   :vim_performance_states, :as => :resource
  delegate   :my_zone, :to => :ext_management_system, :allow_nil => true

  include EventMixin
  include Metric::CiMixin

  acts_as_miq_taggable

  def event_where_clause_ems_events
    # TODO: improve relationship using the id
    EmsEvent
      .where(:container_name => name)
      .where(:container_namespace => container_project.try(:name))
      .where(:ems_id => ext_management_system.try(:id))
  end

  def event_where_clause_miq_events
    # TODO: implement policy events and its relationship
    MiqEvent.where(:ems_id => ext_management_system.try(:id))
  end

  PERF_ROLLUP_CHILDREN = []

  def perf_rollup_parents(interval_name = nil)
    # No rollups for nodes performance - they are collected separately
    [container_image].compact unless interval_name == 'realtime'
  end

  def disconnect_inv
    return if archived?
    _log.info("Disconnecting Container [#{name}] id [#{id}] from EMS")
    self.deleted_on = Time.now.utc
    save
  end
end
