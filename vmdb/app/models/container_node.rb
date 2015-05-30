class ContainerNode < ActiveRecord::Base
  include ReportableMixin
  include NewWithTypeStiMixin

  # :name, :uid, :creation_timestamp, :resource_version
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many   :container_groups
  has_many   :container_node_conditions, :dependent => :destroy
  has_one    :computer_system, :as => :managed_entity, :dependent => :destroy
  belongs_to :lives_on, :polymorphic => true

  delegate   :hardware, :to => :computer_system

  virtual_column :ready_condition_status, :type => :string, :uses => :container_node_conditions

  def ready_condition
    container_node_conditions.find_by_name('Ready')
  end

  def ready_condition_status
    ready_condition.try(:status) || 'None'
  end

  include EventMixin

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events
      # TODO: improve relationship using the id
      ["container_node_name = ? AND ems_id = ?", name, ems_id]
    when :policy_events
      # TODO: implement policy events and its relationship
      ["ems_id = ?", ems_id]
    end
  end

  # Metrics destroy is handled by purger
  has_many :metrics, :as => :resource
  has_many :metric_rollups, :as => :resource
  has_many :vim_performance_states, :as => :resource

  include Metric::CiMixin

  # TODO: children will be container groups
  PERF_ROLLUP_CHILDREN = nil

  acts_as_miq_taggable

  delegate :my_zone, :to => :ext_management_system

  def perf_rollup_parent(_interval_name = nil)
    ext_management_system
  end
end
