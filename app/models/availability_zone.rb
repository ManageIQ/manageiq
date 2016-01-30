class AvailabilityZone < ApplicationRecord
  include NewWithTypeStiMixin
  include ReportableMixin
  include Metric::CiMixin
  include EventMixin
  include ProviderObjectMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
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
    where(arel_table[:type].not_eq("ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull"))
  end

  PERF_ROLLUP_CHILDREN = :vms

  def perf_rollup_parents(interval_name = nil)
    [ext_management_system].compact unless interval_name == 'realtime'
  end

  def total_vms
    vms.size
  end

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def event_where_clause(assoc = :ems_events)
    ["#{events_table_name(assoc)}.availability_zone_id = ?", id]
  end
end
