class Chargeback < ActsAsArModel
  set_columns_hash( # Fields common to any chargeback type
    :start_date           => :datetime,
    :end_date             => :datetime,
    :interval_name        => :string,
    :display_range        => :string,
    :chargeback_rates     => :string,
    :entity               => :binary,
    :tag_name             => :string,
    :fixed_compute_metric => :integer,
  )

  VIRTUAL_COL_USES = {
    "v_derived_cpu_total_cores_used" => "cpu_usage_rate_average"
  }

  def self.build_results_for_report_chargeback(options)
    _log.info("Calculating chargeback costs...")
    @options = options = ReportOptions.new_from_h(options)

    rates = RatesCache.new

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

      hours_in_interval = hours_in_interval(query_start_time, query_end_time)

      # we are building hash with grouped calculated values
      # values are grouped by resource_id and timestamp (query_start_time...query_end_time)
      records.group_by(&:resource_id).each do |_, metric_rollup_records|
        metric_rollup_records = metric_rollup_records.select { |x| x.resource.present? }
        consumption = Consumption.new(metric_rollup_records, hours_in_interval)
        next if metric_rollup_records.empty?

        # we need to select ChargebackRates for groups of MetricRollups records
        # and rates are selected by first MetricRollup record
        metric_rollup_record = metric_rollup_records.first
        rates_to_apply = rates.get(metric_rollup_record)

        # key contains resource_id and timestamp (query_start_time...query_end_time)
        # extra_fields there some extra field like resource name and
        # some of them are related to specific chargeback (ChargebackVm, ChargebackContainer,...)
        key, extra_fields = key_and_fields(metric_rollup_record)
        data[key] ||= new(extra_fields)

        chargeback_rates = data[key]["chargeback_rates"].split(', ') + rates_to_apply.collect(&:description)
        data[key]["chargeback_rates"] = chargeback_rates.uniq.join(', ')

        # we are getting hash with metrics and costs for metrics defined for chargeback
        data[key].calculate_costs(consumption, rates_to_apply)
      end
    end

    _log.info("Calculating chargeback costs...Complete")

    [data.values]
  end

  def self.hours_in_interval(query_start_time, query_end_time)
    (query_end_time - query_start_time).round / 1.hour
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

  def calculate_costs(consumption, rates)
    self.fixed_compute_metric = consumption.chargeback_fields_present if consumption.chargeback_fields_present

    rates.each do |rate|
      rate.chargeback_rate_details.each do |r|
        r.charge(relevant_fields, consumption).each do |field, value|
          next unless self.class.attribute_names.include?(field)
          self[field] = (self[field] || 0) + value
        end
      end
    end
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

  def self.set_chargeback_report_options(rpt, group_by, header_for_tag, tz)
    rpt.cols = %w(start_date display_range)

    static_cols       = group_by == "project" ? report_static_cols - ["image_name"] : report_static_cols
    static_cols       = group_by == "tag" ? [report_tag_field] : static_cols
    rpt.cols         += static_cols
    rpt.col_order     = static_cols + ["display_range"]
    rpt.sortby        = static_cols + ["start_date"]

    rpt.col_order.each do |c|
      header_column = (c == report_tag_field && header_for_tag) ? header_for_tag : c
      rpt.headers.push(Dictionary.gettext(header_column, :type => :column, :notfound => :titleize))
      rpt.col_formats.push(nil) # No formatting needed on the static cols
    end

    rpt.col_options = report_col_options
    rpt.order = "Ascending"
    rpt.group = "y"
    rpt.tz = tz
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

  private

  def relevant_fields
    @relevant_fields ||= self.class.report_col_options.keys.to_set
  end
end # class Chargeback
