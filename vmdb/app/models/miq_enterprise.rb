class MiqEnterprise < ActiveRecord::Base
  has_many :miq_regions,            lambda { |_| MiqRegion.scoped }
  has_many :ext_management_systems, lambda { |_| ExtManagementSystem.scoped }
  has_many :vms_and_templates,      lambda { |_| VmOrTemplate.where("ems_id IS NOT NULL") }
  has_many :vms,                    lambda { |_| Vm.where("ems_id IS NOT NULL") }
  has_many :miq_templates,          lambda { |_| MiqTemplate.where("ems_id IS NOT NULL") }
  has_many :hosts,                  lambda { |_| Host.where("ems_id IS NOT NULL") }
  has_many :storages,               lambda { |_| Storage.scoped }
  has_many :policy_events,          lambda { |_| PolicyEvent.scoped }

  has_many :metrics,        :as => :resource  # Destroy will be handled by purger
  has_many :metric_rollups, :as => :resource  # Destroy will be handled by purger
  has_many :vim_performance_states, :as => :resource  # Destroy will be handled by purger

  serialize :settings

  acts_as_miq_taggable

  include AggregationMixin
  # Since we've overridden the implementation of methods from AggregationMixin,
  # we must also override the :uses portion of the virtual columns.
  override_aggregation_mixin_virtual_columns_uses(:all_hosts, :hosts)
  override_aggregation_mixin_virtual_columns_uses(:all_vms_and_templates, :vms_and_templates)

  include MiqPolicyMixin
  include Metric::CiMixin

  def self.seed
    MiqRegion.my_region.lock do
      if self.in_my_region.first.nil?
        $log.info("MIQ(MiqEnterprise.seed) Creating Enterprise Root Object")
        self.create(:name => "Enterprise", :description => "Enterprise Root Object")
        $log.info("MIQ(MiqEnterprise.seed) Creating Enterprise Root Object... Complete")
      end
    end
  end

  def self.my_enterprise
    # Cache the enterprise instance, but clear the association
    #   cache to support keeping the associations fresh
    @my_enterprise ||= self.in_my_region.first
    @my_enterprise.clear_association_cache unless @my_enterprise.nil?
    @my_enterprise
  end

  def self.is_enterprise?
    # TODO: Need to implement a way to determine whether we're running on an "enterprise" server or a "regional" server.
    #       This will do for now...
    MiqRegion.count > 1
  end

  def is_enterprise?
    self.class.is_enterprise?
  end

  def my_zone
    MiqServer.my_zone
  end

  alias all_vms_and_templates  vms_and_templates
  alias all_vm_or_template_ids vm_or_template_ids
  alias all_vms                vms
  alias all_vm_ids             vm_ids
  alias all_miq_templates      miq_templates
  alias all_miq_template_ids   miq_template_ids
  alias all_hosts              hosts
  alias all_host_ids           host_ids
  alias all_storages           storages

  def get_reserve(field)
    self.ext_management_systems.inject(0) {|v,obj| v + (obj.send(field) || 0)}
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

  def perf_rollup_parent(interval_name=nil)
    nil
  end

  def perf_capture_enabled
    @perf_capture_enabled ||= self.ext_management_systems.any?(&:perf_capture_enabled?)
  end
  alias perf_capture_enabled? perf_capture_enabled
end #class MiqEnterprise
