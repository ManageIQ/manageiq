module Metric::Common
  extend ActiveSupport::Concern
  included do
    belongs_to  :resource, :polymorphic => true
    belongs_to  :time_profile
    has_many    :vim_performance_tag_values, :as => :metric, :dependent => :destroy

    belongs_to  :parent_host,        :class_name => "Host"
    belongs_to  :parent_ems_cluster, :class_name => "EmsCluster"
    belongs_to  :parent_storage,     :class_name => "Storage"
    belongs_to  :parent_ems,         :class_name => "ExtManagementSystem"

    validates :timestamp, :presence => true

    scope :daily,    -> { where(:capture_interval_name => 'daily') }
    scope :hourly,   -> { where(:capture_interval_name => 'hourly') }
    scope :realtime, -> { where(:capture_interval_name => 'realtime') }

    include ReportableMixin

    serialize :assoc_ids
    serialize :min_max   # TODO: Move this to MetricRollup

    virtual_column :v_derived_storage_used, :type => :float

    [
      :cpu_ready_delta_summation,
      :cpu_wait_delta_summation,
      :cpu_used_delta_summation
    ].each do |c|
      vcol = "v_pct_#{c}".to_sym
      virtual_column vcol, :type => :float
      define_method(vcol) { v_calc_pct_of_cpu_time(vcol) }
    end

    attr_accessor :inside_time_profile, :time_profile_adjusted_timestamp

    virtual_column :v_date, :type => :datetime
    virtual_column :v_time, :type => :datetime

    virtual_column :v_derived_vm_count,            :type => :integer
    virtual_column :v_derived_host_count,          :type => :integer
    virtual_column :v_derived_cpu_reserved_pct,    :type => :float
    virtual_column :v_derived_memory_reserved_pct, :type => :float
    virtual_column :v_derived_logical_cpus_used,   :type => :float
  end

  def v_find_min_max(vcol)
    interval, mode = vcol.to_s.split("_")[1..2]
    col = vcol.to_s.split("_")[3..-1].join("_")

    return nil unless interval == "daily" && capture_interval == 1.day

    cond = ["resource_type = ? and resource_id = ? and capture_interval_name = 'hourly' and timestamp >= ? and timestamp < ?",
            resource_type, resource_id, timestamp.to_date.to_s,  (timestamp + 1.day).to_date.to_s]
    direction = mode == "min" ? "ASC" : "DESC"
    rec = MetricRollup.where(cond).order("#{col} #{direction}").first
    rec.nil? ? nil : rec.send(col)
  end

  def v_derived_storage_used
    return nil if derived_storage_total.nil? || derived_storage_free.nil?
    derived_storage_total - derived_storage_free
  end

  def min_max_v_derived_storage_used(mode)
    cond = ["resource_type = ? and resource_id = ? and capture_interval_name = 'hourly' and timestamp >= ? and timestamp < ?",
            resource_type, resource_id, timestamp.to_date.to_s, (timestamp + 1.day).to_date.to_s]
    meth = mode == :min ? :first : :last
    recs = MetricRollup.where(cond)
    rec = recs.sort { |a, b| (a.v_derived_storage_used && b.v_derived_storage_used) ? (a.v_derived_storage_used <=> b.v_derived_storage_used) : (a.v_derived_storage_used ? 1 : -1) }.send(meth)
    rec.nil? ? nil : rec.v_derived_storage_used
  end

  def min_v_derived_storage_used
    @min_v_derived_storage_used ||= min_max_v_derived_storage_used(:min)
  end

  def max_v_derived_storage_used
    @max_v_derived_storage_used ||= min_max_v_derived_storage_used(:max)
  end

  CHILD_ROLLUP_INTERVAL = {
    "realtime" => [20, 1],
    "hourly"   => [20, 60 * Metric::Capture::REALTIME_METRICS_PER_MINUTE],
    "daily"    => [1.hour, 24]
  }
  def v_calc_pct_of_cpu_time(vcol)
    col = vcol.to_s.split("_")[2..-1].join("_")
    return nil if send(col).nil?

    int, default_intervals_in_rollup = CHILD_ROLLUP_INTERVAL[capture_interval_name]
    ints_in_rollup = if capture_interval_name == 'hourly'
                       resource_type == 'VmOrTemplate' ? (intervals_in_rollup || default_intervals_in_rollup) : default_intervals_in_rollup
                     else
                       1 # Special case daily because the value for that interval is and average for 1 hour
                     end
    elapsed_time = (ints_in_rollup * int * 1000.0)
    return 0 if elapsed_time == 0

    raw_val = ((send(col) / elapsed_time))

    # A different calculation is necessary for Host, Cluster, EMS, etc.
    # We need to divide by the number of running VMs since the is an aggregation of the millisend values of all the child VMs
    unless resource_type == 'VmOrTemplate'
      return 0 if derived_vm_count_on.nil? || derived_vm_count_on == 0
      raw_val = (raw_val / derived_vm_count_on)
    end

    (raw_val * 1000.0).round / 10.0
  end

  def v_date
    timestamp
  end

  def v_time
    timestamp
  end

  def v_derived_vm_count
    (derived_vm_count_on || 0) + (derived_vm_count_off || 0)
  end

  def v_derived_host_count
    (derived_host_count_on || 0) + (derived_host_count_off || 0)
  end

  def v_derived_cpu_reserved_pct
    return nil if derived_cpu_reserved.nil? || derived_cpu_available.nil? || derived_cpu_available == 0
    (derived_cpu_reserved / derived_cpu_available * 100)
  end

  def v_derived_memory_reserved_pct
    return nil if derived_memory_reserved.nil? || derived_memory_available.nil? || derived_memory_available == 0
    (derived_memory_reserved / derived_memory_available * 100)
  end

  def v_derived_logical_cpus_used
    return nil if cpu_usage_rate_average.nil? || derived_vm_numvcpus.nil? || derived_vm_numvcpus == 0
    (cpu_usage_rate_average * derived_vm_numvcpus) / 100.0
  end

  def apply_time_profile(profile)
    method = "apply_time_profile_#{capture_interval_name}"
    return send(method, profile) if self.respond_to?(method)
  end

  def apply_time_profile_hourly(profile)
    unless profile.ts_in_profile?(timestamp)
      self.inside_time_profile = false
      nil_out_values_for_apply_time_profile
      _log.debug("Hourly Timestamp: [#{timestamp}] is outside of time profile: [#{profile.description}]")
    else
      self.inside_time_profile = true
    end
    inside_time_profile
  end

  def apply_time_profile_daily(profile)
    unless profile.ts_day_in_profile?(timestamp)
      self.inside_time_profile = false
      nil_out_values_for_apply_time_profile
      _log.debug("Daily Timestamp: [#{timestamp}] is outside of time profile: [#{profile.description}]")
    else
      self.inside_time_profile = true
    end
    inside_time_profile
  end

  def nil_out_values_for_apply_time_profile
    (Metric::Rollup::ROLLUP_COLS + ["assoc_ids", "min_max"]).each { |c| send("#{c}=", nil) }
  end
end
