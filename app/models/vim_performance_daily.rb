class VimPerformanceDaily < MetricRollup
  def self.instances_are_derived?; true; end

  INFO_COLS = [:resource_type, :resource_id, :resource_name]

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
  ] + Metric::Rollup::STORAGE_COLS

  EXCLUDED_COLS_FOR_EXPRESSIONS = Metric::Rollup::ROLLUP_COLS - INFREQUENTLY_CHANGING_COLS

  def self.excluded_cols_for_expressions
    EXCLUDED_COLS_FOR_EXPRESSIONS
  end

  def self.find(cnt, *args)
    raise "Unsupported finder value #{cnt}" unless cnt == :all

    ActiveSupport::Deprecation.warn "VimPerformanceDaily#find(:all) is deprecated; please use #find_entries instead", caller

    options = args.last.is_a?(Hash) ? args.last : {}
    ext_options = options.delete(:ext_options) || {}
    find_entries(ext_options)
      .apply_legacy_finder_options(options)
      .to_a
  end

  def self.default_time_profile(ext_options)
    if (tz = Metric::Helper.get_time_zone(ext_options))
      # Determine if this search falls into an existing valid TimeProfile
      TimeProfile.rollup_daily_metrics.find_all_with_entire_tz.detect { |p| p.tz_or_default == tz }
    end
  end

  def self.find_entries(ext_options)
    ext_options ||= {}
    ext_options[:time_profile] ||= default_time_profile(ext_options)

    find_by_time_profile(ext_options)
  end

  def self.find_by_time_profile(ext_options)
    klass = ext_options[:class] || MetricRollup

    # Support for multi-region DB. We need to try to find a time profile in each
    # region that matches the selected profile to ensure that we get results for
    # all the regions in the database. We only want one match from each region
    # otherwise we'll end up with duplicate daily rows.
    if (tp = ext_options[:time_profile]) && tp.rollup_daily_metrics
      tps = TimeProfile.rollup_daily_metrics.select { |p| p.profile == tp.profile }.group_by(&:region_id).values.flatten
      tp_ids = tps.collect(&:id)

      klass.where(:time_profile_id => tp_ids, :capture_interval_name => 'daily')
    else
      klass.none
    end
  end

  def self.find_adhoc(*args)
    []
  end


  def self.generate_daily_for_one_day(recs, options = {})
    self.process_hashes(self.process_hourly_for_one_day(recs, options), options.merge(:save => false))
  end

  def self.process_hourly_for_one_day(recs, options = {})
    return [] if recs.blank?

    process_only_cols(options)
    _log.debug("Limiting cols to: #{options[:only_cols].inspect}")

    result = {}
    counts = {}

    tz = Metric::Helper.get_time_zone(options)
    tp = options[:time_profile]

    # Get ts in desired time zone
    ts = recs.first.timestamp.in_time_zone(tz)
    # Convert to midnight in desired timezone to strip off hours to just get the date
    ts = ts.beginning_of_day

    recs.each do |perf|
      next unless perf.capture_interval_name == "hourly"

      rtype = perf.resource_type
      rid   = perf.resource_id

      key = [perf.capture_interval_name, rtype, rid]
      result[key] ||= {}
      counts[key] ||= {}

      INFO_COLS.each { |c| result[key][c] = perf.send(c) } if result[key].empty?

      if tp && tp.ts_in_profile?(perf.timestamp) == false
        # Save timestamp and info cols for daily row but don't aggregate any values
        _log.debug("Timestamp: [#{perf.timestamp.in_time_zone(tz)}] is outside of time profile: [#{tp.description}]")
        next
      end

      (Metric::Rollup::ROLLUP_COLS & (options[:only_cols] || Metric::Rollup::ROLLUP_COLS)).each do |c|
        result[key][c] ||= 0
        counts[key][c] ||= 0
        value = perf.send(c)
        value = value * 1.0 unless value.nil?

        # Average all values, regardless of rollup type, when going from hourly
        # to daily, since these are already rolled up and this is an average
        # over the day.
        Metric::Aggregation::Aggregate.average(c, nil, result[key], counts[key], value)

        Metric::Rollup.rollup_min(c, result[key], perf.send(c))
        Metric::Rollup.rollup_max(c, result[key], perf.send(c))
      end
      if rtype == 'VmOrTemplate' && perf.min_max.kind_of?(Hash)
        result[key][:min_max] ||= {}
        (Metric::Rollup::BURST_COLS & (options[:only_cols] || Metric::Rollup::BURST_COLS)).each do |c|
          Metric::Rollup::BURST_TYPES.each do |type|
            ts_key, val_key = Metric::Rollup.burst_col_names(type, c)
            # check the hourly row's min_max column's value for a key such as: "abs_min_mem_usage_absolute_average_value"
            Metric::Rollup.rollup_burst(c, result[key][:min_max], perf.min_max[ts_key], perf.min_max[val_key], type)
          end
        end
      end

      Metric::Rollup.rollup_assoc(:assoc_ids, result[key], perf.assoc_ids) if options[:only_cols].nil? || options[:only_cols].include?(:assoc_ids)
      Metric::Rollup.rollup_tags(:tag_names, result[key], perf.tag_names)  if options[:only_cols].nil? || options[:only_cols].include?(:tag_names)

      [:parent_host_id, :parent_ems_cluster_id, :parent_storage_id, :parent_ems_id].each do |c|
        val = perf.send(c)
        result[key][c] = val if val && (options[:only_cols].nil? || options[:only_cols].include?(c))
      end

      (options[:reflections] || []).each do |assoc|
        next if perf.class.virtual_field?(assoc)
        result[key][assoc.to_sym] = perf.send(assoc) if perf.respond_to?(assoc)
      end
    end

    ts_utc = ts.utc.to_time

    # Don't bother rolling up values if day is outside of time profile
    rollup_day = tp.nil? || tp.ts_day_in_profile?(ts)

    results = []
    result.each_key do |key|
      int, rtype, rid = key

      if rollup_day
        (Metric::Rollup::ROLLUP_COLS & (options[:only_cols] || Metric::Rollup::ROLLUP_COLS)).each { |c|
          Metric::Aggregation::Process.average(c, nil, result[key], counts[key])
          result[key][c] = result[key][c].round if self.columns_hash[c.to_s].type == :integer && !result[key][c].nil?
        }
      else
        _log.debug("Daily Timestamp: [#{ts}] is outside of time profile: [#{tp.description}]")
      end

      results.push(result[key].merge(
        :timestamp             => ts_utc,
        :resource_type         => rtype,
        :resource_id           => rid,
        :capture_interval      => 1.day,
        :capture_interval_name => "daily",
        :intervals_in_rollup   => Metric::Helper.max_count(counts[key])
      ))
    end

    # Clean up min_max values that are stored directly by moving into min_max property Hash
    results.each do |h|
      min_max = h.delete(:min_max)

      h[:min_max] = h.keys.find_all {|k| k.to_s.starts_with?("min") || k.to_s.starts_with?("max")}.inject({}) do |mm,k|
        val = h.delete(k)
        mm[k] = val unless val.nil?
        mm
      end
      h[:min_max].merge!(min_max) if min_max.is_a?(Hash)
    end

    return results
  end

  def self.process_hashes(results, options={:save => true})
    klass = options[:class] || self
    results.inject([]) do |a,h|
      if options[:save]
        perf = self.find_by_timestamp_and_capture_interval_name_and_resource_type_and_resource_id(
          h[:timestamp], h[:capture_interval_name], h[:resource_type], h[:resource_id]
        )

        perf ? perf.update_attributes!(h) : perf = self.create(h)

        VimPerformanceTagValue.build_from_performance_record(perf) if options[:save]
      else
        perf = klass.new(h)
      end

      a << perf
    end
  end

  def self.process_only_cols(options)
    unless options[:only_cols].nil?
      options[:only_cols] =  options[:only_cols].collect(&:to_sym) if options[:only_cols]
      options[:only_cols] += options[:only_cols].collect {|c| c.to_s[4..-1].to_sym if c.to_s.starts_with?("min_") || c.to_s.starts_with?("max_")}.compact
      options[:only_cols] += options[:only_cols].collect {|c| c.to_s.split("_")[2..-2].join("_").to_sym if c.to_s.starts_with?("abs_")}.compact
      options[:only_cols] += [:cpu_ready_delta_summation, :cpu_wait_delta_summation, :cpu_used_delta_summation] if options[:only_cols].find {|c| c.to_s.starts_with?("v_pct_")}
      options[:only_cols] += [:derived_storage_total, :derived_storage_free] if options[:only_cols].include?(:v_derived_storage_used)
      options[:only_cols] += Metric::BASE_COLS.collect(&:to_sym)
    end
  end

end #class VimPerformanceDaily
