class VimPerformanceDaily < MetricRollup
  def self.instances_are_derived?; true; end

  INFO_COLS = [:resource_type, :resource_id, :resource_name]
  PARENT_COLS = [:parent_host_id, :parent_ems_cluster_id, :parent_storage_id, :parent_ems_id].freeze

  # @param ext_options [Hash] search options
  # @opts ext_options :klass [Class] class for metrics (default: MetricRollup)
  # @opts ext_options :time_profile [TimeProfile]
  # @opts ext_options :tz [Timezone] (default: DEFAULT_TIMEZONE)
  def self.find_entries(ext_options)
    ext_options ||= {}
    # TODO: remove changing ext_options once this side effect is no longer needed:
    time_profile = ext_options[:time_profile] ||= TimeProfile.default_time_profile(ext_options[:tz])
    klass = Metric::Helper.class_for_interval_name("daily", ext_options[:class])

    klass.with_time_profile_or_tz(time_profile || ext_options[:tz]).where(:capture_interval_name => 'daily')
  end

  def self.process_hourly_for_one_day(recs, options = {})
    only_cols = process_only_cols(recs)
    result = {}
    counts = {}

    tz = Metric::Helper.get_time_zone(options)
    tp = options[:time_profile]

    ts = nil

    recs.each do |perf|
      # Get ts in desired time zone - converted to local midnight to strip off hours and become a date
      ts ||= recs.first.timestamp.in_time_zone(tz).beginning_of_day
      rtype = perf.resource_type
      rid   = perf.resource_id

      key = [perf.capture_interval_name, rtype, rid]
      result[key] ||= INFO_COLS.each_with_object({}) { |c, h| h[c] = perf.send(c) }
      counts[key] ||= {}

      if tp && tp.ts_in_profile?(perf.timestamp) == false
        # Save timestamp and info cols for daily row but don't aggregate any values
        _log.debug("Timestamp: [#{perf.timestamp.in_time_zone(tz)}] is outside of time profile: [#{tp.description}]")
        next
      end

      relevant_cols(Metric::Rollup::ROLLUP_COLS, only_cols).each do |c|
        result[key][c] ||= 0
        counts[key][c] ||= 0
        value = perf.send(c)
        value *= 1.0 unless value.nil?

        # Average all values, regardless of rollup type, when going from hourly
        # to daily, since these are already rolled up and this is an average
        # over the day.
        Metric::Aggregation::Aggregate.average(c, nil, result[key], counts[key], value)

        Metric::Rollup.rollup_min(c, result[key], value)
        Metric::Rollup.rollup_max(c, result[key], value)
      end
      if rtype == 'VmOrTemplate' && perf.min_max.kind_of?(Hash)
        result[key][:min_max] ||= {}

        relevant_cols(Metric::Rollup::BURST_COLS, only_cols).each do |c|
          Metric::Rollup::BURST_TYPES.each do |type|
            ts_key, val_key = Metric::Rollup.burst_col_names(type, c)
            # check the hourly row's min_max column's value for a key such as: "abs_min_mem_usage_absolute_average_value"
            Metric::Rollup.rollup_burst(c, result[key][:min_max], perf.min_max[ts_key], perf.min_max[val_key], type)
          end
        end
      end

      Metric::Rollup.rollup_assoc(:assoc_ids, result[key], perf.assoc_ids) if only_cols.nil? || only_cols.include?(:assoc_ids)
      Metric::Rollup.rollup_tags(:tag_names, result[key], perf.tag_names)  if only_cols.nil? || only_cols.include?(:tag_names)

      relevant_cols(PARENT_COLS, only_cols).each do |c|
        val = perf.send(c)
        result[key][c] = val if val
      end

      (options[:reflections] || []).each do |assoc|
        next if perf.class.virtual_field?(assoc)
        result[key][assoc.to_sym] = perf.send(assoc) if perf.respond_to?(assoc)
      end
    end

    return [] if result.empty?
    ts_utc = ts.utc.to_time

    # Don't bother rolling up values if day is outside of time profile
    rollup_day = tp.nil? || tp.ts_day_in_profile?(ts)

    results = result.each_key.collect do |key|
      _int, rtype, rid = key

      if rollup_day
        rollup_columns = (Metric::Rollup::ROLLUP_COLS & (only_cols || Metric::Rollup::ROLLUP_COLS))
        average_columns = rollup_columns - Metric::Rollup::DAILY_SUM_COLUMNS

        average_columns.each do |c|
          Metric::Aggregation::Process.average(c, nil, result[key], counts[key])
        end
        rollup_columns.each do |c|
          result[key][c] = result[key][c].round if columns_hash[c.to_s].type == :integer && !result[key][c].nil?
        end
      else
        _log.debug("Daily Timestamp: [#{ts}] is outside of time profile: [#{tp.description}]")
      end

      result[key].merge(
        :timestamp             => ts_utc,
        :resource_type         => rtype,
        :resource_id           => rid,
        :capture_interval      => 1.day,
        :capture_interval_name => "daily",
        :intervals_in_rollup   => Metric::Helper.max_count(counts[key])
      )
    end

    # Clean up min_max values that are stored directly by moving into min_max property Hash
    results.each do |h|
      min_max = h.delete(:min_max)

      h[:min_max] = h.keys.find_all { |k| k.to_s.starts_with?("min", "max") }.inject({}) do |mm, k|
        val = h.delete(k)
        mm[k] = val unless val.nil?
        mm
      end
      h[:min_max].merge!(min_max) if min_max.kind_of?(Hash)
    end

    results
  end

  def self.relevant_cols(cols, only_cols)
    only_cols ? (cols & only_cols) : cols
  end

  def self.process_only_cols(recs)
    only_cols = recs.select_values.collect(&:to_sym).presence
    return unless only_cols
    only_cols += only_cols.select { |c| c.to_s.starts_with?("min_", "max_") }.collect { |c| c.to_s[4..-1].to_sym }
    only_cols += only_cols.select { |c| c.to_s.starts_with?("abs_") }.collect { |c| c.to_s.split("_")[2..-2].join("_").to_sym }
    if only_cols.detect { |c| c.to_s.starts_with?("v_pct_") }
      only_cols += [:cpu_ready_delta_summation, :cpu_wait_delta_summation, :cpu_used_delta_summation]
    end
    only_cols += [:derived_storage_total, :derived_storage_free] if only_cols.include?(:v_derived_storage_used)
    only_cols += Metric::BASE_COLS.collect(&:to_sym)
    only_cols.uniq
  end
end # class VimPerformanceDaily
