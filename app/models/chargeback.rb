class Chargeback < ActsAsArModel
  HOURS_IN_DAY = 24
  HOURS_IN_WEEK = 168

  VIRTUAL_COL_USES = {
    "v_derived_cpu_total_cores_used" => "cpu_usage_rate_average"
  }

  def self.build_results_for_report_chargeback(options)
    _log.info("Calculating chargeback costs...")

    tz = Metric::Helper.get_time_zone(options[:ext_options])
    # TODO: Support time profiles via options[:ext_options][:time_profile]

    interval = options[:interval] || "daily"
    cb = new

    options[:ext_options] ||= {}

    base_rollup = MetricRollup.includes(
      :resource           => [:hardware, :tenant],
      :parent_host        => :tags,
      :parent_ems_cluster => :tags,
      :parent_storage     => :tags,
      :parent_ems         => :tags)
                              .select(*Metric::BASE_COLS).order("resource_id, timestamp")
    perf_cols = MetricRollup.attribute_names
    rate_cols = ChargebackRate.where(:default => true).flat_map do |rate|
      rate.chargeback_rate_details.map(&:metric).select { |metric| perf_cols.include?(metric.to_s) }
    end

    rate_cols.map! { |x| VIRTUAL_COL_USES.include?(x) ? VIRTUAL_COL_USES[x] : x }.flatten!
    base_rollup = base_rollup.select(*rate_cols)

    timerange = get_report_time_range(options, interval, tz)
    data = {}

    interval_duration = interval_to_duration(interval)

    timerange.step_value(interval_duration).each_cons(2) do |query_start_time, query_end_time|
      records = base_rollup.where(:timestamp => query_start_time...query_end_time, :capture_interval_name => "hourly")
      records = where_clause(records, options)
      records = Metric::Helper.remove_duplicate_timestamps(records)
      next if records.empty?
      _log.info("Found #{records.length} records for time range #{[query_start_time, query_end_time].inspect}")

      hours_in_interval = hours_in_interval(query_start_time, query_end_time, interval)

      # we are building hash with grouped calculated values
      # values are grouped by resource_id and timestamp (query_start_time...query_end_time)
      records.group_by(&:resource_id).each do |_, metric_rollup_records|
        metric_rollup_records = metric_rollup_records.select { |x| x.resource.present? }
        next if metric_rollup_records.empty?

        # we need to select ChargebackRates for groups of MetricRollups records
        # and rates are selected by first MetricRollup record
        metric_rollup_record = metric_rollup_records.first
        rates_to_apply = cb.get_rates(metric_rollup_record)

        # key contains resource_id and timestamp (query_start_time...query_end_time)
        # extra_fields there some extra field like resource name and
        # some of them are related to specific chargeback (ChargebackVm, ChargebackContainer,...)
        key, extra_fields = key_and_fields(metric_rollup_record, interval, tz)
        data[key] ||= extra_fields

        # we are getting hash with metrics and costs for metrics defined for chargeback
        metrics_and_costs = calculate_costs(metric_rollup_records, rates_to_apply, hours_in_interval)

        data[key].merge!(metrics_and_costs)
      end
    end

    _log.info("Calculating chargeback costs...Complete")

    [data.map { |r| new(r.last) }]
  end

  def self.hours_in_interval(query_start_time, query_end_time, interval)
    return HOURS_IN_DAY if interval == "daily"
    return HOURS_IN_WEEK if interval == "weekly"

    (query_end_time - query_start_time) / 1.hour
  end

  def self.interval_to_duration(interval)
    case interval
    when "daily"
      1.day
    when "weekly"
      1.week
    when "monthly"
      1.month
    end
  end

  def self.key_and_fields(metric_rollup_record, interval, tz)
    ts_key = get_group_key_ts(metric_rollup_record, interval, tz)

    key, extra_fields = get_keys_and_extra_fields(metric_rollup_record, ts_key)

    [key, date_fields(metric_rollup_record, interval, tz).merge(extra_fields)]
  end

  def self.date_fields(metric_rollup_record, interval, tz)
    start_ts, end_ts, display_range = get_time_range(metric_rollup_record, interval, tz)

    {
      'start_date'    => start_ts,
      'end_date'      => end_ts,
      'display_range' => display_range,
      'interval_name' => interval
    }
  end

  def get_rates(perf)
    @rates ||= {}
    @enterprise ||= MiqEnterprise.my_enterprise

    tags = perf.tag_names.split("|").reject { |n| n.starts_with?("folder_path_") }.sort.join("|")
    keys = [tags, perf.parent_host_id, perf.parent_ems_cluster_id, perf.parent_storage_id, perf.parent_ems_id]
    tenant_resource = perf.resource.try(:tenant)
    keys.push(tenant_resource.id) unless tenant_resource.nil?
    key = keys.join("_")
    return @rates[key] if @rates.key?(key)

    tag_list = perf.tag_names.split("|").inject([]) { |arr, t| arr << "vm/tag/managed/#{t}"; arr }

    parents = [perf.parent_host, perf.parent_ems_cluster, perf.parent_storage, perf.parent_ems, @enterprise].compact
    parents.push(tenant_resource) unless tenant_resource.nil?

    @rates[key] = ChargebackRate.get_assigned_for_target(perf.resource, :tag_list => tag_list, :parents => parents)
  end

  def self.calculate_costs(metric_rollup_records, rates, hours_in_interval)
    calculated_costs = {}

    rates.each do |rate|
      rate.chargeback_rate_details.each do |r|
        r.hours_in_interval = hours_in_interval
        metric_value = r.metric_value_by(metric_rollup_records)
        cost = r.cost(metric_value) * hours_in_interval

        # add values to hash and sum
        reportable_metric_and_cost_fields(r.rate_name, r.group, metric_value, cost).each do |k, val|
          next unless attribute_names.include?(k)
          calculated_costs[k] ||= 0
          calculated_costs[k] += val
        end
      end
    end

    calculated_costs
  end

  def self.reportable_metric_and_cost_fields(rate_name, rate_group, metric, cost)
    cost_key         = "#{rate_name}_cost"    # metric cost value (e.g. Storage [Used|Allocated|Fixed] Cost)
    metric_key       = "#{rate_name}_metric"  # metric value (e.g. Storage [Used|Allocated|Fixed])
    cost_group_key   = "#{rate_group}_cost"   # for total of metric's costs (e.g. Storage Total Cost)
    metric_group_key = "#{rate_group}_metric" # for total of metrics (e.g. Storage Total)

    col_hash = {}

    defined_column_for_report = (report_col_options.keys & [metric_key, cost_key]).present?

    if defined_column_for_report
      [metric_key, metric_group_key].each             { |col| col_hash[col] = metric }
      [cost_key,   cost_group_key, 'total_cost'].each { |col| col_hash[col] = cost }
    end

    col_hash
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

  def self.report_cb_model(model)
    model.gsub(/^Chargeback/, "")
  end

  def self.db_is_chargeback?(db)
    db && db.safe_constantize < Chargeback
  end

  def self.report_tag_field
    "tag_name"
  end
end # class Chargeback
