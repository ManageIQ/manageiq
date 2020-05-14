class MiqEnterprise < ApplicationRecord
  has_many :metrics,        :as => :resource  # Destroy will be handled by purger
  has_many :metric_rollups, :as => :resource  # Destroy will be handled by purger
  has_many :vim_performance_states, :as => :resource  # Destroy will be handled by purger

  virtual_has_many :miq_regions,             :class_name => "MiqRegion"
  virtual_has_many :ext_management_systems,  :class_name => "ExtManagementSystem"
  virtual_has_many :vms_and_templates,       :class_name => "VmOrTemplate"
  virtual_has_many :vms,                     :class_name => "Vm"
  virtual_has_many :miq_templates,           :class_name => "MiqTemplate"
  virtual_has_many :hosts,                   :class_name => "Host"
  virtual_has_many :storages,                :class_name => "Storage"
  virtual_has_many :policy_events,           :class_name => "PolicyEvent"

  serialize :settings

  acts_as_miq_taggable

  include SupportsFeatureMixin
  include MiqPolicyMixin
  include Metric::CiMixin

  def self.seed
    in_my_region.first || create!(:name => "Enterprise", :description => "Enterprise Root Object") do |_|
      _log.info("Creating Enterprise Root Object")
    end
  end

  cache_with_timeout(:my_enterprise) { in_my_region.first }

  def my_zone
    MiqServer.my_zone
  end

  def miq_regions
    MiqRegion.all
  end

  def ext_management_systems
    ExtManagementSystem.all
  end

  def vms_and_templates
    VmOrTemplate.where.not(:ems_id => nil)
  end

  def vms
    Vm.where.not(:ems_id => nil)
  end

  def miq_templates
    MiqTemplate.where.not(:ems_id => nil)
  end

  def hosts
    Host.where.not(:ems_id => nil)
  end

  def storages
    Storage.all
  end

  def policy_events
    PolicyEvent.all
  end

  alias_method :all_storages,           :storages

  def get_reserve(field)
    ext_management_systems.inject(0) { |v, obj| v + (obj.send(field) || 0) }
  end

  def cpu_reserve
    get_reserve(:cpu_reserve)
  end

  def memory_reserve
    get_reserve(:memory_reserve)
  end

  #
  # Metric methods
  #

  PERF_ROLLUP_CHILDREN = [:miq_regions]

  def perf_rollup_parents(_interval_name = nil)
    # No rollup parents
  end

  def perf_capture_enabled?
    @perf_capture_enabled ||= ext_management_systems.any?(&:perf_capture_enabled?)
  end
  alias_method :perf_capture_enabled, :perf_capture_enabled?
  Vmdb::Deprecation.deprecate_methods(self, :perf_capture_enabled => :perf_capture_enabled?)

  def self.display_name(number = 1)
    n_('Enterprise', 'Enterprises', number)
  end
end # class MiqEnterprise
