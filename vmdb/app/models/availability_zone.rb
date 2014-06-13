class AvailabilityZone < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin
  include Metric::CiMixin
  include EventMixin
  include ProviderObjectMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id
  has_many   :vms
  has_many   :vms_and_templates
  has_many   :cloud_volumes
  has_many   :cloud_subnets
  has_many   :metrics,                :as => :resource
  has_many   :metric_rollups,         :as => :resource
  has_many   :vim_performance_states, :as => :resource
  has_many   :ems_events

  acts_as_miq_taggable

  virtual_column :total_vms, :type => :integer, :uses => :vms

  def self.available
    where(arel_table[:type].not_eq("AvailabilityZoneOpenstackNull"))
  end

  PERF_ROLLUP_CHILDREN = :vms

  def perf_rollup_parent(interval_name=nil)
    self.ext_management_system unless interval_name == 'realtime'
  end

  def total_vms
    vms.size
  end

  def my_zone
    ems = self.ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def event_where_clause(assoc=:ems_events)
    case assoc.to_sym
    when :ems_events
      ["availability_zone_id = ?", self.id]
    when :policy_events
      ["availability_zone_id = ?", self.id]
    end
  end
end
