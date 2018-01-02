module Metric::Common
  extend ActiveSupport::Concern
  included do
    belongs_to  :resource, :polymorphic => true
    belongs_to  :time_profile

    belongs_to  :parent_host,        :class_name => "Host"
    belongs_to  :parent_ems_cluster, :class_name => "EmsCluster"
    belongs_to  :parent_storage,     :class_name => "Storage"
    belongs_to  :parent_ems,         :class_name => "ExtManagementSystem"

    validates :timestamp, :presence => true

    scope :daily,    -> { where(:capture_interval_name => 'daily') }
    scope :hourly,   -> { where(:capture_interval_name => 'hourly') }
    scope :realtime, -> { where(:capture_interval_name => 'realtime') }

    serialize :assoc_ids
    serialize :min_max   # TODO: Move this to MetricRollup

    virtual_column :v_derived_storage_used, :type => :float, :arel => (lambda do |t|
      t.grouping(t[:derived_storage_total] - t[:derived_storage_free])
    end)

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

    virtual_column :v_date,  :type => :datetime
    virtual_column :v_month, :type => :string
    virtual_column :v_time,  :type => :datetime

    virtual_column :v_derived_vm_count,             :type => :integer
    virtual_column :v_derived_host_count,           :type => :integer
    virtual_column :v_derived_cpu_reserved_pct,     :type => :float
    virtual_column :v_derived_memory_reserved_pct,  :type => :float
    virtual_column :v_derived_cpu_total_cores_used, :type => :float
  end

  def v_derived_storage_used
    return nil if derived_storage_total.nil? || derived_storage_free.nil?
    derived_storage_total - derived_storage_free
  end

  def min_max_v_derived_storage_used(mode)
    recs = MetricRollup.where(:resource_type => resource_type, :resource_id => resource_id)
                       .where(:capture_interval_name => 'hourly')
                       .where('timestamp >= ? and timestamp < ?', # This picks only the first midnight
                              timestamp.to_date, (timestamp + 1.day).to_date)
                       .where.not(:derived_storage_total => nil, :derived_storage_free => nil)
    recs.send(mode, MetricRollup.arel_attribute(:v_derived_storage_used))
  end

  def min_v_derived_storage_used
    @min_v_derived_storage_used ||= min_max_v_derived_storage_used(:minimum)
  end

  def max_v_derived_storage_used
    @max_v_derived_storage_used ||= min_max_v_derived_storage_used(:maximum)
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

  def v_month
    timestamp.strftime("%Y/%m")
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

  def v_derived_cpu_total_cores_used
    return nil if cpu_usage_rate_average.nil? || derived_vm_numvcpus.nil? || derived_vm_numvcpus == 0
    (cpu_usage_rate_average * derived_vm_numvcpus) / 100.0
  end

  # Applies the given time profile to this metric record
  # unless record already refer to some time profile (which were used for aggregation)
  def apply_time_profile(profile)
    if time_profile_id || profile.ts_in_profile?(timestamp)
      self.inside_time_profile = true
    else
      self.inside_time_profile = false
      nil_out_values_for_apply_time_profile
      _log.debug("Hourly Timestamp: [#{timestamp}] is outside of time profile: [#{profile.description}]")
    end
    inside_time_profile
  end

  def nil_out_values_for_apply_time_profile
    (Metric::Rollup::ROLLUP_COLS + ["assoc_ids", "min_max"]).each { |c| send("#{c}=", nil) }
  end

  class_methods do
    def for_tag_names(*args)
      where("tag_names like ?", "%" + args.join("/") + "%")
    end

    def for_time_range(start_time, end_time)
      if start_time.nil?
        none
      elsif start_time == end_time
        where(:timestamp => start_time)
      elsif end_time.nil?
        where(arel_table[:timestamp].gteq(start_time))
      else
        where(:timestamp => start_time..end_time)
      end
    end

    # @param :time_profile_or_tz [TimeProfile|Timezone] (default: DEFAULT_TIMEZONE)
    def with_time_profile_or_tz(time_profile_or_tz = nil)
      if (time_profile = TimeProfile.default_time_profile(time_profile_or_tz))
        tp_ids = time_profile.profile_for_each_region
        where(:time_profile => tp_ids)
      else
        none
      end
    end

    def with_interval_and_time_range(interval, timestamp)
      where(:capture_interval_name => interval, :timestamp => timestamp)
    end

    def with_resource
      where.not(:resource => nil)
    end
  end
end
