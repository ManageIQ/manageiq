class Container < ActiveRecord::Base
  include ReportableMixin
  include NewWithTypeStiMixin

  belongs_to :container_group
  belongs_to :container_definition

  # Metrics destroy is handled by purger
  has_many :metrics, :as => :resource
  has_many :metric_rollups, :as => :resource
  has_many :vim_performance_states, :as => :resource

  include Metric::CiMixin

  PERF_ROLLUP_CHILDREN = nil

  acts_as_miq_taggable

  delegate :my_zone, :to => :container_group
  delegate :ext_management_system, :to => :container_group
  delegate :container_node, :to => :container_group

  def perf_rollup_parent(_interval_name = nil)
    # No rollups: nodes performance are collected separately
  end
end
