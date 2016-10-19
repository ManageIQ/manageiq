class Chargeback < ActsAsArModel
  HOURS_IN_DAY = 24
  HOURS_IN_WEEK = 168

  VIRTUAL_COL_USES = {
    "v_derived_cpu_total_cores_used" => "cpu_usage_rate_average"
  }

  def self.build_results_for_report_chargeback(options)
    _log.info("Calculating chargeback costs...")
    @options = options = ReportOptions.new_from_h(options)

    cb = new

    base_rollup = MetricRollup.includes(
      :resource           => [:hardware, :tenant, :tags, :vim_performance_states, :custom_attributes],
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

    timerange = options.report_time_range
    data = {}

    interval_duration = options.duration_of_report_step

    timerange.step_value(interval_duration).each_cons(2) do |query_start_time, query_end_time|
      records = base_rollup.where(:timestamp => query_start_time...query_end_time, :capture_interval_name => "hourly")
      records = where_clause(records, options)
      records = Metric::Helper.remove_duplicate_timestamps(records)
      next if records.empty?
      _log.info("Found #{records.length} records for time range #{[query_start_time, query_end_time].inspect}")

      hours_in_interval = hours_in_interval(query_start_time, query_end_time, options.interval)

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
        key, extra_fields = key_and_fields(metric_rollup_record)
        data[key] ||= new(extra_fields)

        chargeback_rates = data[key]["chargeback_rates"].split(', ') + rates_to_apply.collect(&:description)
        data[key]["chargeback_rates"] = chargeback_rates.uniq.join(', ')

        # we are getting hash with metrics and costs for metrics defined for chargeback
        data[key].calculate_costs(metric_rollup_records, rates_to_apply, hours_in_interval)
      end
    end

    _log.info("Calculating chargeback costs...Complete")

    [data.values]
  end

  def self.hours_in_interval(query_start_time, query_end_time, interval)
    return HOURS_IN_DAY if interval == "daily"
    return HOURS_IN_WEEK if interval == "weekly"

    (query_end_time - query_start_time) / 1.hour
  end

  def self.key_and_fields(metric_rollup_record)
    ts_key = @options.start_of_report_step(metric_rollup_record.timestamp)

    key, extra_fields = if @options[:groupby_tag].present?
                          get_tag_keys_and_fields(metric_rollup_record, ts_key)
                        else
                          get_keys_and_extra_fields(metric_rollup_record, ts_key)
                        end

    [key, date_fields(metric_rollup_record).merge(extra_fields)]
  end

  def self.date_fields(metric_rollup_record)
    start_ts, end_ts, display_range = @options.report_step_range(metric_rollup_record.timestamp)

    {
      'start_date'       => start_ts,
      'end_date'         => end_ts,
      'display_range'    => display_range,
      'interval_name'    => @options.interval,
      'chargeback_rates' => '',
      'entity'           => metric_rollup_record.resource
    }
  end

  def self.get_tag_keys_and_fields(perf, ts_key)
    tag = perf.tag_names.split("|").select { |x| x.starts_with?(@options[:groupby_tag]) }.first # 'department/*'
    tag = tag.split('/').second unless tag.blank? # 'department/finance' -> 'finance'
    classification = @options.tag_hash[tag]
    classification_id = classification.present? ? classification.id : 'none'
    key = "#{classification_id}_#{ts_key}"
    extra_fields = { "tag_name" => classification.present? ? classification.description : _('<Empty>') }
    [key, extra_fields]
  end

  def get_rates(perf)
    @rates ||= {}
    @rates[perf.hash_features_affecting_rate] ||=
      begin
        prefix = Chargeback.report_cb_model(self.class.name).underscore
        ChargebackRate.get_assigned_for_target(perf.resource,
                                               :tag_list => perf.tag_list_reconstruct.map! { |t| prefix + t },
                                               :parents  => get_rate_parents(perf).compact)
      end
  end

  def calculate_costs(metric_rollup_records, rates, hours_in_interval)
    chargeback_fields_present = metric_rollup_records.count(&:chargeback_fields_present?)
    self.fixed_compute_metric = chargeback_fields_present if chargeback_fields_present

    rates.each do |rate|
      rate.chargeback_rate_details.each do |r|
        if !chargeback_fields_present && r.fixed?
          cost = 0
        else
          metric_value = r.metric_value_by(metric_rollup_records)
          r.hours_in_interval = hours_in_interval
          cost = r.cost(metric_value) * hours_in_interval
        end

        self.class.reportable_metric_and_cost_fields(r.rate_name, r.group, metric_value, cost).each do |k, val|
          next unless self.class.attribute_names.include?(k)
          self[k] ||= 0
          self[k] += val
        end
      end
    end
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

  def self.report_cb_model(model)
    model.gsub(/^Chargeback/, "")
  end

  def self.db_is_chargeback?(db)
    db && db.present? && db.safe_constantize < Chargeback
  end

  def self.report_tag_field
    "tag_name"
  end

  def self.get_rate_parents
    raise "Chargeback: get_rate_parents must be implemented in child class."
  end

  def self.set_chargeback_report_options(rpt, edit)
    rpt.cols = %w(start_date display_range)

    static_cols = report_static_cols
    if edit[:new][:cb_groupby] == "date"
      rpt.cols += static_cols
      rpt.col_order = ["display_range"] + static_cols
      rpt.sortby = ["start_date"] + static_cols
    elsif edit[:new][:cb_groupby] == "vm"
      rpt.cols += static_cols
      rpt.col_order = static_cols + ["display_range"]
      rpt.sortby = static_cols + ["start_date"]
    elsif edit[:new][:cb_groupby] == "tag"
      tag_col = report_tag_field
      rpt.cols += [tag_col]
      rpt.col_order = [tag_col, "display_range"]
      rpt.sortby = [tag_col, "start_date"]
    elsif edit[:new][:cb_groupby] == "project"
      static_cols -= ["image_name"]
      rpt.cols += static_cols
      rpt.col_order = static_cols + ["display_range"]
      rpt.sortby = static_cols + ["start_date"]
    end
    rpt.col_order.each do |c|
      if c == tag_col
        header = edit[:cb_cats][edit[:new][:cb_groupby_tag]]
        rpt.headers.push(Dictionary.gettext(header, :type => :column, :notfound => :titleize)) if header
      else
        rpt.headers.push(Dictionary.gettext(c, :type => :column, :notfound => :titleize))
      end

      rpt.col_formats.push(nil) # No formatting needed on the static cols
    end

    rpt.col_options = report_col_options
    rpt.order = "Ascending"
    rpt.group = "y"
    rpt.tz = edit[:new][:tz]
    rpt
  end

  def tags
    entity.try(:tags).to_a
  end

  def self.load_custom_attributes_for(cols)
    chargeback_klass = report_cb_model(self.to_s).safe_constantize
    chargeback_klass.load_custom_attributes_for(cols)
    cols.each do |x|
      next unless x.include?(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX)

      load_custom_attribute(x)
    end
  end

  def self.load_custom_attribute(custom_attribute)
    virtual_column(custom_attribute.to_sym, :type => :string)

    define_method(custom_attribute.to_sym) do
      entity.send(custom_attribute)
    end
  end
end # class Chargeback
