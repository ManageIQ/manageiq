class HostAggregate < ApplicationRecord
  include SupportsFeatureMixin
  include NewWithTypeStiMixin
  include Metric::CiMixin
  include EventMixin
  include ProviderObjectMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"

  has_many   :host_aggregate_hosts, :dependent => :destroy
  has_many   :hosts,             :through => :host_aggregate_hosts
  has_many   :vms,               :through => :hosts
  has_many   :vms_and_templates, :through => :hosts
  has_many   :metrics,                :as => :resource
  has_many   :metric_rollups,         :as => :resource
  has_many   :vim_performance_states, :as => :resource

  virtual_total :total_vms, :vms

  PERF_ROLLUP_CHILDREN = [:vms]

  def perf_rollup_parents(interval_name = nil)
    # don't rollup to ext_management_system since that's handled through availability zone
    nil
  end

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end
end
