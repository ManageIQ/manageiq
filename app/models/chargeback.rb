class Chargeback < ActsAsArModel
  def self.build_results_for_report_chargeback(options)
    _log.info("Calculating chargeback costs...")

    tz = Metric::Helper.get_time_zone(options[:ext_options])
    # TODO: Support time profiles via options[:ext_options][:time_profile]

    interval = options[:interval] || "daily"
    cb = new

    options[:ext_options] ||= {}

    base_rollup = MetricRollup.includes(
      :resource           => :hardware,
      :parent_host        => :tags,
      :parent_ems_cluster => :tags,
      :parent_storage     => :tags,
      :parent_ems         => :tags)
                              .select(*Metric::BASE_COLS).order("resource_id, timestamp")
    perf_cols = MetricRollup.attribute_names
    rate_cols = ChargebackRate.where(:default => true).flat_map do |rate|
      rate.chargeback_rate_details.map(&:metric).select { |metric| perf_cols.include?(metric.to_s) }
    end
    base_rollup = base_rollup.select(*rate_cols)

    timerange = get_report_time_range(options, interval, tz)
    data = {}

    timerange.step_value(1.day).each_cons(2) do |query_start_time, query_end_time|
      recs = base_rollup.where(:timestamp => query_start_time...query_end_time, :capture_interval_name => "hourly")
      recs = where_clause(recs, options)
      recs = Metric::Helper.remove_duplicate_timestamps(recs)
      _log.info("Found #{recs.length} records for time range #{[query_start_time, query_end_time].inspect}")

      unless recs.empty?
        ts_key = get_group_key_ts(recs.first, interval, tz)

        recs.each do |perf|
          next if perf.resource.nil?
          key, extra_fields = get_keys_and_extra_fields(perf, ts_key)

          if data[key].nil?
            start_ts, end_ts, display_range = get_time_range(perf, interval, tz)
            data[key] = {
              "start_date"    => start_ts,
              "end_date"      => end_ts,
              "display_range" => display_range,
              "interval_name" => interval,
            }.merge(extra_fields)
          end

          rates_to_apply = cb.get_rates(perf)
          calculate_costs(perf, data[key], rates_to_apply)
        end
      end
    end
    _log.info("Calculating chargeback costs...Complete")

    [data.map { |r| new(r.last) }]
  end

  def get_rates(perf)
    @rates ||= {}
    @enterprise ||= MiqEnterprise.my_enterprise

    tags = perf.tag_names.split("|").reject { |n| n.starts_with?("folder_path_") }.sort.join("|")
    key = "#{tags}_#{perf.parent_host_id}_#{perf.parent_ems_cluster_id}_#{perf.parent_storage_id}_#{perf.parent_ems_id}"
    return @rates[key] if @rates.key?(key)

    tag_list = perf.tag_names.split("|").inject([]) { |arr, t| arr << "vm/tag/managed/#{t}"; arr }

    parents = [perf.parent_host, perf.parent_ems_cluster, perf.parent_storage, perf.parent_ems, @enterprise].compact

    @rates[key] = ChargebackRate.get_assigned_for_target(perf.resource, :tag_list => tag_list, :parents => parents, :associations_preloaded => true)
  end

  def self.calculate_costs(perf, h, rates)
    # This expects perf interval to be hourly. That will be the most granular interval available for chargeback.
    unless perf.capture_interval_name == "hourly"
      raise _("expected 'hourly' performance interval but got '%{interval}") % {:interval => perf.capture_interval_name}
    end

    rates.each do |rate|
      rate.chargeback_rate_details.each do |r|
        cost_key         = "#{r.rate_name}_cost"
        metric_key       = "#{r.rate_name}_metric"
        cost_group_key   = "#{r.group}_cost"
        metric_group_key = "#{r.group}_metric"

        rec    = r.metric && perf.respond_to?(r.metric) ? perf : perf.resource
        metric = r.metric.nil? ? 0 : rec.send(r.metric) || 0
        cost   = r.cost(metric)

        col_hash = {}
        [metric_key, metric_group_key].each             { |col| col_hash[col] = metric }
        [cost_key,   cost_group_key, 'total_cost'].each { |col| col_hash[col] = cost   }

        col_hash.each do |k, val|
          next unless attribute_names.include?(k)
          h[k] ||= 0
          h[k] += val
        end
      end
    end
  end

  def self.get_group_key_ts(perf, interval, tz)
    ts = perf.timestamp.in_time_zone(tz)
    case interval
    when "daily"
      ts = ts.beginning_of_day
    when "weekly"
      ts = ts.beginning_of_week
    when "monthly"
      ts = ts.beginning_of_month
    else
      raise _("interval '%{interval}' is not supported") % {:interval => interval}
    end

    ts
  end

  def self.get_time_range(perf, interval, tz)
    ts = perf.timestamp.in_time_zone(tz)
    case interval
    when "daily"
      [ts.beginning_of_day, ts.end_of_day, ts.strftime("%m/%d/%Y")]
    when "weekly"
      s_ts = ts.beginning_of_week
      e_ts = ts.end_of_week
      [s_ts, e_ts, "Week of #{s_ts.strftime("%m/%d/%Y")}"]
    when "monthly"
      s_ts = ts.beginning_of_month
      e_ts = ts.end_of_month
      [s_ts, e_ts, "#{s_ts.strftime("%b %Y")}"]
    else
      raise _("interval '%{interval}' is not supported") % {:interval => interval}
    end
  end

  # @option options :start_time [DateTime] used with :end_time to create time range
  # @option options :end_time [DateTime]
  # @option options :interval_size [Fixednum] Used with :end_interval_offset to generate time range
  # @option options :end_interval_offset
  def self.get_report_time_range(options, interval, tz)
    return options[:start_time]..options[:end_time] if options[:start_time]
    raise _("Option 'interval_size' is required") if options[:interval_size].nil?

    end_interval_offset = options[:end_interval_offset] || 0
    start_interval_offset = (end_interval_offset + options[:interval_size] - 1)

    ts = Time.now.in_time_zone(tz)
    case interval
    when "daily"
      start_time = (ts - start_interval_offset.days).beginning_of_day.utc
      end_time   = (ts - end_interval_offset.days).end_of_day.utc
    when "weekly"
      start_time = (ts - start_interval_offset.weeks).beginning_of_week.utc
      end_time   = (ts - end_interval_offset.weeks).end_of_week.utc
    when "monthly"
      start_time = (ts - start_interval_offset.months).beginning_of_month.utc
      end_time   = (ts - end_interval_offset.months).end_of_month.utc
    else
      raise _("interval '%{interval}' is not supported") % {:interval => interval}
    end

    start_time..end_time
  end
end # class Chargeback
