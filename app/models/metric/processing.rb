module Metric::Processing
  DERIVED_COLS = [
    :derived_cpu_available,
    :derived_cpu_reserved,
    :derived_host_count_off,
    :derived_host_count_on,
    :derived_host_count_total,
    :derived_memory_available,
    :derived_memory_reserved,
    :derived_memory_used,
    :derived_host_sockets,
    :derived_vm_allocated_disk_storage,
    :derived_vm_count_off,
    :derived_vm_count_on,
    :derived_vm_count_total,
    :derived_vm_numvcpus, # TODO: This is cpu_total_cores and needs to be renamed, but reports depend on the name :numvcpus
    # See also #TODO on VimPerformanceState.capture
    :derived_vm_used_disk_storage,
    # TODO(lsmola) as described below, this field should be named derived_cpu_used
    :cpu_usagemhz_rate_average
  ]

  VALID_PROCESS_TARGETS = [
    VmOrTemplate,
    Container,
    ContainerGroup,
    Host,
    ContainerNode,
    AvailabilityZone,
    EmsCluster,
    ExtManagementSystem,
    MiqRegion,
    MiqEnterprise
  ]

  def self.process_derived_columns(obj, attrs, ts = nil)
    raise "object #{obj} is not one of #{VALID_PROCESS_TARGETS.collect(&:name).join(", ")}" unless VALID_PROCESS_TARGETS.any? { |t| obj.kind_of?(t) }

    ts = attrs[:timestamp] if ts.nil?
    state = obj.vim_performance_state_for_ts(ts)
    total_cpu = state.total_cpu || 0
    total_mem = state.total_mem || 0
    result = {}

    have_cpu_metrics = attrs[:cpu_usage_rate_average] || attrs[:cpu_usagemhz_rate_average]
    have_mem_metrics = attrs[:mem_usage_absolute_average]

    DERIVED_COLS.each do |col|
      dummy, group, typ, mode = col.to_s.split("_")
      case typ
      when "available"
        # Do not derive "available" values if there haven't been any usage
        # values collected
        if group == "cpu"
          result[col] = total_cpu if have_cpu_metrics && total_cpu > 0
        else
          result[col] = total_mem if have_mem_metrics && total_mem > 0
        end
      when "allocated"
        method = col.to_s.split("_")[1..-1].join("_")
        result[col] = state.send(method) if state.respond_to?(method)
      when "used"
        if group == "cpu"
          # TODO: This branch is never called because there isn't a column
          # called derived_cpu_used.  The callers, such as chargeback, generally
          # use cpu_usagemhz_rate_average directly, and the column may not be
          # needed, but perhaps should be added to normalize like is done for
          # memory.  The derivation here could then use cpu_usagemhz_rate_average
          # directly if avaiable, otherwise do the calculation below.
          result[col] = (attrs[:cpu_usage_rate_average] / 100 * total_cpu) unless total_cpu == 0 || attrs[:cpu_usage_rate_average].nil?
        elsif group == "memory"
          result[col] = (attrs[:mem_usage_absolute_average] / 100 * total_mem) unless total_mem == 0 || attrs[:mem_usage_absolute_average].nil?
        else
          method = col.to_s.split("_")[1..-1].join("_")
          result[col] = state.send(method) if state.respond_to?(method)
        end
      when "rate"
        if col.to_s == "cpu_usagemhz_rate_average" && attrs[:cpu_usagemhz_rate_average].blank?
          # TODO(lsmola) for some reason, this column is used in chart, although from processing code above, it should
          # be named derived_cpu_used. Investigate what is the right solution and make it right. For now lets fill
          # the column shown in charts.
          result[col] = (attrs[:cpu_usage_rate_average] / 100 * total_cpu) unless total_cpu == 0 || attrs[:cpu_usage_rate_average].nil?
        end
      when "reserved"
        method = group == "cpu" ? :reserve_cpu : :reserve_mem
        result[col] = state.send(method)
      when "count"
        method = [group, typ, mode].join("_")
        result[col] = state.send(method)
      when "numvcpus" # This is actually logical cpus.  See note above.
        # Do not derive "available" values if there haven't been any usage
        # values collected
        result[col] = state.numvcpus if obj.kind_of?(VmOrTemplate) && have_cpu_metrics && state.numvcpus.to_i > 0
      when "sockets"
        result[col] = state.host_sockets
      end
    end

    result[:assoc_ids] = state.assoc_ids
    result[:tag_names] = state.tag_names
    result[:parent_host_id] = state.parent_host_id
    result[:parent_storage_id] = state.parent_storage_id
    result[:parent_ems_id] = state.parent_ems_id
    result[:parent_ems_cluster_id] = state.parent_ems_cluster_id
    result
  end

  def self.add_missing_intervals(obj, interval_name, start_time, end_time)
    klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)

    cond = Metric::Helper.range_to_condition(start_time, end_time)
    if interval_name != "realtime"
      cond[0] << " AND capture_interval_name = ?"
      cond << interval_name
    end

    last_perf = {}
    obj.send(meth).all(:conditions => cond, :order => "timestamp, capture_interval_name").each do |perf|
      interval = interval_name_to_interval(perf.capture_interval_name)
      last_perf[interval] = perf if last_perf[interval].nil?

      if (perf.timestamp - last_perf[interval].timestamp) <= interval
        last_perf[interval] = perf
        next
      end

      new_perf = klass.new(last_perf[interval].attributes)
      new_perf.timestamp = last_perf[interval].timestamp + interval
      new_perf.capture_interval = 0
      Metric::Rollup::ROLLUP_COLS.each do |c|
        next if new_perf.send(c).nil? || perf.send(c).nil?
        new_perf.send(c.to_s + "=", (new_perf.send(c) + perf.send(c)) / 2)
      end

      unless perf.assoc_ids.nil?
        Metric::Rollup::ASSOC_KEYS.each do |assoc|
          next if new_perf.assoc_ids.nil? || new_perf.assoc_ids[assoc].blank? || perf.assoc_ids[assoc].blank?
          new_perf.assoc_ids[assoc][:on] ||= []
          new_perf.assoc_ids[assoc][:off] ||= []
          new_perf.assoc_ids[assoc][:on]  = (new_perf.assoc_ids[assoc][:on] + perf.assoc_ids[assoc][:on]).uniq!
          new_perf.assoc_ids[assoc][:off] = (new_perf.assoc_ids[assoc][:off] + perf.assoc_ids[assoc][:off]).uniq!
        end
      end
      new_perf.save

      last_perf[interval] = perf
    end
  end

  def self.interval_name_to_interval(name)
    case name
    when "realtime" then 20
    when "hourly" then   1.hour.to_i
    when "daily" then    1.day.to_i
    else             raise "unknown interval name: [#{name}]"
    end
  end
end
