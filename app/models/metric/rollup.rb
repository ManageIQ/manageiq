module Metric::Rollup
  ROLLUP_COLS  = Metric.columns_hash.collect { |c, h| c.to_sym if h.type == :float || c[0, 7] == "derived" }.compact +
                 [:stat_container_group_create_rate,
                  :stat_container_group_delete_rate,
                  :stat_container_image_registration_rate]
  STORAGE_COLS = Metric.columns_hash.collect { |c, _h| c.to_sym if c.starts_with?("derived_storage_") }.compact

  NON_STORAGE_ROLLUP_COLS = (ROLLUP_COLS - STORAGE_COLS)

  AGGREGATE_COLS = {
    :MiqEnterprise_miq_regions            => ROLLUP_COLS,
    :MiqRegion_ext_management_systems     => NON_STORAGE_ROLLUP_COLS,
    :MiqRegion_storages                   => STORAGE_COLS,
    :ExtManagementSystem_hosts            => NON_STORAGE_ROLLUP_COLS,
    :ExtManagementSystem_container_nodes  => NON_STORAGE_ROLLUP_COLS,
    :EmsCluster_hosts                     => [
      :cpu_ready_delta_summation,
      :cpu_system_delta_summation,
      :cpu_usage_rate_average,
      :cpu_usagemhz_rate_average,
      :cpu_used_delta_summation,
      :cpu_wait_delta_summation,
      :derived_vm_allocated_disk_storage,
      :derived_vm_numvcpus,
      :derived_vm_used_disk_storage,
      :disk_devicelatency_absolute_average,
      :disk_kernellatency_absolute_average,
      :disk_queuelatency_absolute_average,
      :disk_usage_rate_average,
      :mem_usage_absolute_average,
      :net_usage_rate_average,
    ],
    :Host_vms                             => [
      :cpu_ready_delta_summation,
      :cpu_system_delta_summation,
      :cpu_used_delta_summation,
      :cpu_wait_delta_summation,
      :derived_vm_allocated_disk_storage,
      :derived_vm_numvcpus,
      :derived_vm_used_disk_storage,
    ],
    :ContainerProject_all_container_groups => [
      :cpu_usage_rate_average,
      :derived_vm_numvcpus,
      :derived_memory_used,
      :net_usage_rate_average
    ],
    :ContainerService_container_groups    => [
      :cpu_usage_rate_average,
      :derived_vm_numvcpus,
      :derived_memory_used,
      :net_usage_rate_average
    ],
    :ContainerReplicator_container_groups => [
      :cpu_usage_rate_average,
      :derived_vm_numvcpus,
      :derived_memory_used,
      :net_usage_rate_average
    ],
    :AvailabilityZone_vms                 => [
      :cpu_usage_rate_average,
      :derived_memory_used,
      :net_usage_rate_average,
      :disk_usage_rate_average
    ],
    :HostAggregate_vms                    => [
      :cpu_usage_rate_average,
      :derived_memory_used,
      :net_usage_rate_average,
      :disk_usage_rate_average
    ],
    :Service_vms                           => [
      :cpu_ready_delta_summation,
      :cpu_system_delta_summation,
      :cpu_usage_rate_average,
      :cpu_usagemhz_rate_average,
      :cpu_used_delta_summation,
      :cpu_wait_delta_summation,
      :derived_vm_allocated_disk_storage,
      :derived_vm_numvcpus,
      :derived_vm_used_disk_storage,
      :derived_memory_used,
      :derived_memory_available,
      :disk_devicelatency_absolute_average,
      :disk_kernellatency_absolute_average,
      :disk_queuelatency_absolute_average,
      :disk_usage_rate_average,
      :mem_usage_absolute_average,
      :net_usage_rate_average,
    ]
  }

  VM_REALTIME_COLS = [
    # Collected from VC
    :cpu_ready_delta_summation,
    :cpu_system_delta_summation,
    :cpu_usage_rate_average,
    :cpu_usagemhz_rate_average,
    :cpu_used_delta_summation,
    :cpu_wait_delta_summation,
    :disk_usage_rate_average,
    :mem_swapin_absolute_average,
    :mem_swapout_absolute_average,
    :mem_swapped_absolute_average,
    :mem_swaptarget_absolute_average,
    :mem_usage_absolute_average,
    :mem_vmmemctl_absolute_average,
    :mem_vmmemctltarget_absolute_average,
    :net_usage_rate_average,
    :sys_uptime_absolute_latest,
    # Derived
    :v_derived_cpu_reserved_pct,
    :v_derived_memory_reserved_pct,
    :v_pct_cpu_ready_delta_summation,
    :v_pct_cpu_used_delta_summation,
    :v_pct_cpu_wait_delta_summation
  ]

  HOST_REALTIME_COLS = [
    # Collected from VC
    :cpu_usage_rate_average,
    :cpu_usagemhz_rate_average,
    :cpu_used_delta_summation,
    :disk_devicelatency_absolute_average,
    :disk_kernellatency_absolute_average,
    :disk_queuelatency_absolute_average,
    :disk_usage_rate_average,
    :mem_swapin_absolute_average,
    :mem_swapout_absolute_average,
    :mem_usage_absolute_average,
    :mem_vmmemctl_absolute_average,
    :net_usage_rate_average,
    :sys_uptime_absolute_latest,
    # Derived
    :derived_cpu_available,
    :derived_memory_available,
    :derived_memory_used
  ]

  EMS_CLUSTER_REALTIME_COLS = HOST_REALTIME_COLS

  INFREQUENTLY_CHANGING_COLS = [
    :derived_cpu_available,
    :derived_cpu_reserved,
    :derived_host_count_off,
    :derived_host_count_on,
    :derived_memory_available,
    :derived_memory_reserved,
    :derived_vm_allocated_disk_storage,
    :derived_vm_count_off,
    :derived_vm_count_on,
    :derived_vm_numvcpus,
  ].freeze

  def self.excluded_col_for_expression?(col)
    NON_STORAGE_ROLLUP_COLS.include?(col) && !INFREQUENTLY_CHANGING_COLS.include?(col)
  end

  # these columns will pass false for aggregate_only to Aggregation::Process.column
  # this means that when processing the totals for a parent rollup, the total
  # values will be averaged across the number of children
  AVG_VALUE_COLUMNS = [
    :cpu_usage_rate_average
  ]

  DAILY_SUM_COLUMNS = [
    :stat_container_group_create_rate,
    :stat_container_group_delete_rate,
    :stat_container_image_registration_rate
  ].freeze
  BURST_COLS = [
    :cpu_usage_rate_average,
    :cpu_usagemhz_rate_average,
    :disk_usage_rate_average,
    :mem_usage_absolute_average,
    :derived_memory_used,
    :net_usage_rate_average
  ]
  BURST_TYPES = ['min', 'max']

  ASSOC_KEYS = [:vms, :hosts]

  TIMEOUT_PROCESS = 30.minutes.to_i
  DERIVED_COLS_EXCLUDED_CLASSES = ['MiqRegion', 'MiqEnterprise']
  TAG_SEP = "|"

  def self.rollup_realtime(obj, rt_ts, _interval_name, _time_profile, new_perf, orig_perf)
    # Roll up realtime metrics from child objects
    children = obj.class::PERF_ROLLUP_CHILDREN
    children.each { |c| new_perf.merge!(rollup_child_metrics(obj, rt_ts, 'realtime', c)) } unless children.empty?

    new_perf.reverse_merge!(orig_perf)
    new_perf.merge!(Metric::Processing.process_derived_columns(obj, new_perf, rt_ts)) unless DERIVED_COLS_EXCLUDED_CLASSES.include?(obj.class.base_class.name)

    new_perf
  end

  def self.rollup_hourly(obj, hour, _interval_name, _time_profile, new_perf, orig_perf)
    # Roll up realtime metrics
    rt_perfs = Metric::Finders.find_all_by_hour(obj, hour, 'realtime')
    rollup_realtime_perfs(obj, rt_perfs, new_perf)

    # Roll up hourly metrics from child objects
    children = obj.class::PERF_ROLLUP_CHILDREN
    children.each { |c| new_perf.merge!(rollup_child_metrics(obj, hour, 'hourly', c)) } unless children.empty?

    new_perf.reverse_merge!(orig_perf)
    new_perf.merge!(Metric::Processing.process_derived_columns(obj, new_perf, hour)) unless DERIVED_COLS_EXCLUDED_CLASSES.include?(obj.class.base_class.name)
    new_perf.merge!(Metric::Statistic.calculate_stat_columns(obj, hour))

    new_perf
  end

  class << self
    alias_method :rollup_historical, :rollup_hourly
  end

  def self.rollup_daily(obj, day, interval_name, time_profile, new_perf, orig_perf)
    tp = TimeProfile.extract_objects(time_profile)
    if tp.nil?
      _log.info("Skipping [#{interval_name}] Rollup for #{obj.class.name} name: [#{obj.name}], id: [#{obj.id}] for time: [#{day}] since the time profile no longer exists.")
      return
    end

    hr_perfs = Metric::Finders.find_all_by_day(obj, day, 'hourly', tp)
    daily_perfs = VimPerformanceDaily.process_hourly_for_one_day(hr_perfs, :time_profile => tp, :save => false)

    new_perf.merge!(daily_perfs.first) unless daily_perfs.first.nil?
    new_perf.reverse_merge!(orig_perf)

    new_perf
  end

  def self.rollup_realtime_perfs(obj, rt_perfs, new_perf = {})
    new_perf_counts = {}

    rt_perfs.each do |rt|
      Metric::Capture.capture_cols.each do |col|
        new_perf[col] ||= 0
        new_perf_counts[col] ||= 0

        value = rt.send(col)
        Metric::Aggregation::Aggregate.column(col, nil, new_perf, new_perf_counts, value)
      end

      next unless obj.kind_of?(VmOrTemplate)
      new_perf[:min_max] ||= {}
      BURST_COLS.each do |col|
        value = rt.send(col)
        rollup_burst(col, new_perf[:min_max], rt.timestamp, value)
      end
    end

    new_perf.each_key do |col|
      Metric::Aggregation::Process.column(col, nil, new_perf, new_perf_counts)
    end

    new_perf[:intervals_in_rollup] = Metric::Helper.max_count(new_perf_counts)

    new_perf
  end

  def self.rollup_child_metrics(obj, timestamp, interval_name, assoc)
    ts = timestamp.kind_of?(Time) ? timestamp.utc.iso8601 : timestamp
    recs = obj.send("#{assoc}_from_vim_performance_state_for_ts", timestamp)

    result = {}
    counts = {}

    agg_cols = interval_name == "realtime" ? const_get("#{obj.class.base_class.name.underscore.upcase}_REALTIME_COLS") : AGGREGATE_COLS["#{obj.class.base_class}_#{assoc}".to_sym]
    agg_cols.each do |c|
      # Initialize aggregation col values and counts to zero before starting
      counts[c] = 0
      result[c] = 0
    end

    perf_recs = Metric::Finders.hash_by_capture_interval_name_and_timestamp(recs, ts, ts, interval_name)

    # Preload states for perf timestamp and the current hour. We need to cache
    #   the current hour too because the capture in vim_performance_state_for_ts,
    #   if not found for the perf timestamp, will return a state for the current
    #   hour only.
    MiqPreloader.preload(recs, :vim_performance_states, VimPerformanceState.where(:timestamp => [ts, Metric::Helper.nearest_hourly_timestamp(Time.now.utc)])) unless recs.empty?

    recs.each do |rec|
      perf = perf_recs.fetch_path(rec.class.base_class.name, rec.id, interval_name, ts)
      next unless perf
      state = rec.vim_performance_state_for_ts(timestamp)
      agg_cols.each do |c|
        result[c] ||= 0
        counts[c] ||= 0
        value = perf ? perf.send(c) : 0
        Metric::Aggregation::Aggregate.column(c, state, result, counts, value, :average)
      end
    end

    agg_cols.each do |c|
      aggregate_only = !AVG_VALUE_COLUMNS.include?(c)
      Metric::Aggregation::Process.column(c, obj.vim_performance_state_for_ts(timestamp), result, counts, aggregate_only, :average)
    end

    result
  end

  def self.burst_col_names(type, col)
    prefix = "abs_#{type}_#{col}"
    return "#{prefix}_timestamp".to_sym, "#{prefix}_value".to_sym
  end

  def self.rollup_burst(c, result, timestamp, value, types = nil)
    Array.wrap(types || BURST_TYPES).each do |type|
      ts_key, val_key = burst_col_names(type, c)

      if new_min_max?(result[val_key], value, type)
        result[ts_key] = timestamp
        result[val_key] = value
      end
    end
  end

  def self.new_min_max?(existing, new_value, type)
    case type
    when 'min' then existing.nil? || (new_value && new_value < existing)
    when 'max' then existing.nil? || (new_value && new_value > existing)
    else false
    end
  end

  def self.rollup_min(c, result, value)
    key = "min_#{c}".to_sym
    result[key] = value if result[key].nil? || (value && value < result[key])
  end

  def self.rollup_max(c, result, value)
    key = "max_#{c}".to_sym
    result[key] = value if result[key].nil? || (value && value > result[key])
  end

  def self.rollup_assoc(c, result, value)
    return if value.nil?
    ASSOC_KEYS.each do |assoc|
      next if value[assoc].nil?
      result[c] ||= {}
      result[c][assoc] ||= {}

      [:on, :off].each do |mode|
        next if value[assoc][mode].nil?
        result[c][assoc][mode] ||= []
        result[c][assoc][mode].concat(value[assoc][mode]).uniq!
      end
    end
  end

  def self.rollup_tags(c, result, value)
    return if value.blank?
    result[c] ||= ""
    result[c] = result[c].split(TAG_SEP).concat(value.split(TAG_SEP)).uniq.join(TAG_SEP)
  end

  #
  # Gap collection
  #

  def self.perf_rollup_gap(start_time, end_time, interval_name, time_profile_id = nil)
    targets = find_distinct_resources
    return if targets.empty?

    _log.info("Queueing #{interval_name} rollups for range: [#{start_time} - #{end_time}]...")
    targets.each { |t| t.perf_rollup_range_queue(start_time, end_time, interval_name, time_profile_id, MiqQueue::LOW_PRIORITY) }
    _log.info("Queueing #{interval_name} rollups for range: [#{start_time} - #{end_time}]...Complete")
  end

  def self.perf_rollup_gap_queue(start_time, end_time, interval_name, time_profile_id = nil)
    MiqQueue.put_unless_exists(
      :class_name  => name,
      :method_name => "perf_rollup_gap",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :args        => [start_time, end_time, interval_name, time_profile_id]
    )
  end

  def self.find_distinct_resources
    metrics = Metric.in_my_region.select("DISTINCT resource_type, resource_id")
    metric_rollups = MetricRollup.in_my_region.select("DISTINCT resource_type, resource_id")

    recs = (metrics + metric_rollups).group_by(&:resource_type)
    recs.keys.each { |k| recs[k] = recs[k].collect(&:resource_id).uniq }

    recs.each_with_object([]) do |(klass, ids), ret|
      ret.concat(klass.constantize.where(:id => ids))
    end
  end
end
