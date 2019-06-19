class Chargeback < ActsAsArModel
  set_columns_hash( # Fields common to any chargeback type
    :start_date             => :datetime,
    :end_date               => :datetime,
    :interval_name          => :string,
    :display_range          => :string,
    :report_interval_range  => :string,
    :report_generation_date => :datetime,
    :chargeback_rates       => :string,
    :entity                 => :binary,
    :tag_name               => :string,
    :label_name             => :string,
    :fixed_compute_metric   => :integer,
  )

  ALLOWED_FIELD_SUFFIXES = %w[
    _rate
    _cost
    -owner_name
    _metric
    -report_interval_range
    -report_generation_date
    -provider_name
    -provider_uid
    -project_uid
    -archived
    -chargeback_rates
    -vm_guid
    -vm_uid
  ].freeze

  def self.dynamic_rate_columns
    @chargeable_fields = {}
    @chargeable_fields[self.class] ||=
      begin
        ChargeableField.all.each_with_object({}) do |chargeable_field, result|
          next unless report_col_options.keys.include?("#{chargeable_field.rate_name}_cost")
          result["#{chargeable_field.rate_name}_rate"] = :string
        end
      end
  end

  def self.refresh_dynamic_metric_columns
    set_columns_hash(dynamic_rate_columns)
  end

  def self.build_results_for_report_chargeback(options)
    _log.info("Calculating chargeback costs...")
    @options = options = ReportOptions.new_from_h(options)

    data = {}
    rates = RatesCache.new(options)
    _log.debug("With report options: #{options.inspect}")

    MiqRegion.all.each do |region|
      _log.debug("For region #{region.region}")

      ConsumptionHistory.for_report(self, options, region.region) do |consumption|
        rates_to_apply = rates.get(consumption)

        key = report_row_key(consumption)
        _log.debug("Report row key #{key}")

        data[key] ||= new(options, consumption, region.region)

        chargeback_rates = data[key]["chargeback_rates"].split(', ') + rates_to_apply.collect(&:description)
        data[key]["chargeback_rates"] = chargeback_rates.uniq.join(', ')

        # we are getting hash with metrics and costs for metrics defined for chargeback
        if Settings[:new_chargeback]
          data[key].new_chargeback_calculate_costs(consumption, rates_to_apply)
        else
          data[key].calculate_costs(consumption, rates_to_apply)
        end
      end
    end

    _log.info("Calculating chargeback costs...Complete")

    [data.values]
  end

  def self.report_row_key(consumption)
    ts_key = @options.start_of_report_step(consumption.timestamp)
    if @options[:groupby_tag].present?
      classification = @options.classification_for(consumption)
      classification_id = classification.present? ? classification.id : 'none'
      "#{classification_id}_#{ts_key}"
    elsif @options[:groupby_label].present?
      "#{groupby_label_value(consumption, @options[:groupby_label])}_#{ts_key}"
    elsif @options.group_by_tenant?
      tenant = @options.tenant_for(consumption)
      "#{tenant ? tenant.id : 'none'}_#{ts_key}"
    elsif @options.group_by_date_only?
      ts_key
    else
      default_key(consumption, ts_key)
    end
  end

  def self.default_key(consumption, ts_key)
    "#{consumption.resource_id}_#{ts_key}"
  end

  def self.groupby_label_value(consumption, groupby_label)
    nil
  end

  def initialize(options, consumption, region)
    @options = options
    super()
    if @options[:groupby_tag].present?
      classification = @options.classification_for(consumption)
      self.tag_name = classification.present? ? classification.description : _('<Empty>')
    elsif @options[:groupby_label].present?
      label_value = self.class.groupby_label_value(consumption, options[:groupby_label])
      self.label_name = label_value.present? ? label_value : _('<Empty>')
    else
      init_extra_fields(consumption, region)
    end
    self.start_date, self.end_date, self.display_range = options.report_step_range(consumption.timestamp)
    self.interval_name = options.interval
    self.chargeback_rates = ''
    self.entity ||= consumption.resource
    self.tenant_name = consumption.resource.try(:tenant).try(:name) if options.group_by_tenant?
  end

  def showback_category
    case self
    when ChargebackVm
      'Vm'
    when ChargebackContainerProject
      'Container'
    when ChargebackContainerImage
      'ContainerImage'
    end
  end

  def new_chargeback_calculate_costs(consumption, rates)
    self.fixed_compute_metric = consumption.chargeback_fields_present if consumption.chargeback_fields_present

    rates.each do |rate|
      plan = ManageIQ::Showback::PricePlan.find_or_create_by(:description => rate.description,
                                                             :name        => rate.description,
                                                             :resource    => MiqEnterprise.first)

      data = {}
      rate.rate_details_relevant_to(relevant_fields, self.class.attribute_names).each do |r|
        r.populate_showback_rate(plan, r, showback_category)
        measure = r.chargeable_field.showback_measure
        dimension, _, _ = r.chargeable_field.showback_dimension
        value = r.chargeable_field.measure(consumption, @options)
        data[measure] ||= {}
        data[measure][dimension] = [value, r.showback_unit(ChargeableField::UNITS[r.chargeable_field.metric])]
      end

      # TODO: duration_of_report_step is 30.days for price plans but for consumption history,
      # it's used for date ranges and needs to be 1.month with rails 5.1
      duration = @options.interval == "monthly" ? 30.days : @options.duration_of_report_step
      results = plan.calculate_list_of_costs_input(resource_type:  showback_category,
                                                   data:           data,
                                                   start_time:     consumption.instance_variable_get("@start_time"),
                                                   end_time:       consumption.instance_variable_get("@end_time"),
                                                   cycle_duration: duration)

      results.each do |cost_value, sb_rate|
        r = ChargebackRateDetail.find(sb_rate.concept)
        metric = r.chargeable_field.metric
        metric_index = ChargeableField::VIRTUAL_COL_USES.invert[metric] || metric
        metric_value = data[r.chargeable_field.group][metric_index]
        metric_field = [r.chargeable_field.group, r.chargeable_field.source, "metric"].join("_")
        cost_field = [r.chargeable_field.group, r.chargeable_field.source, "cost"].join("_")
        _, total_metric_field, total_field = r.chargeable_field.cost_keys
        self[total_field] = (self[total_field].to_f || 0) + cost_value.to_f
        self[total_metric_field] = (self[total_metric_field].to_f || 0) + cost_value.to_f
        self[cost_field] = cost_value.to_f
        self[metric_field] = metric_value.first.to_f
      end
    end
  end

  def calculate_fixed_compute_metric(consumption)
    return unless consumption.chargeback_fields_present

    if @options.group_by_date_only?
      self.fixed_compute_metric ||= 0
      self.fixed_compute_metric += consumption.chargeback_fields_present
    else
      self.fixed_compute_metric = consumption.chargeback_fields_present
    end
  end

  def calculate_costs(consumption, rates)
    calculate_fixed_compute_metric(consumption)
    self.class.try(:refresh_dynamic_metric_columns)
    self.report_interval_range = "#{consumption.report_interval_start.strftime('%m/%d/%Y')} - #{consumption.report_interval_end.strftime('%m/%d/%Y')}"
    self.report_generation_date = Time.current

    _log.debug("Consumption Type: #{consumption.class}")
    rates.each do |rate|
      _log.debug("Calculation with rate: #{rate.id} #{rate.description}(#{rate.rate_type})")
      rate.rate_details_relevant_to(relevant_fields, self.class.attribute_names).each do |r|
        _log.debug("Metric: #{r.chargeable_field.metric} Group: #{r.chargeable_field.group} Source: #{r.chargeable_field.source}")
        r.chargeback_tiers.each do |tier|
          _log.debug("Start: #{tier.start} Finish: #{tier.finish} Fixed Rate: #{tier.fixed_rate} Variable Rate: #{tier.variable_rate}")
        end
        r.charge(consumption, @options).each do |field, value|
          next if @options.skip_field_accumulation?(field, self[field])
          _log.debug("Calculation with field: #{field} and with value: #{value}")
          (self[field] = self[field].kind_of?(Numeric) ? (self[field] || 0) + value : value)
          _log.debug("Accumulated value: #{self[field]}")
        end
      end
    end
  end

  def self.report_cb_model(model)
    model.gsub(/^(Chargeback|Metering)/, "")
  end

  def self.db_is_chargeback?(db)
    db && db.present? && db.safe_constantize < Chargeback
  end

  def self.report_tag_field
    "tag_name"
  end

  def self.report_label_field
    "label_name"
  end

  def self.set_chargeback_report_options(rpt, group_by, header_for_tag, groupby_label, tz)
    rpt.cols = %w(start_date display_range)

    static_cols       = report_static_cols
    static_cols      -= ["image_name"] if group_by == "project"
    static_cols      -= ["vm_name"] if group_by == "date-only"
    static_cols       = group_by == "tag" ? [report_tag_field] : static_cols
    static_cols       = group_by == "label" ? [report_label_field] : static_cols
    static_cols       = group_by == "tenant" ? ['tenant_name'] : static_cols
    rpt.cols         += static_cols
    rpt.col_order     = static_cols + ["display_range"]
    rpt.sortby        = static_cols + ["start_date"]

    rpt.col_order.each do |c|
      header_column = if (c == report_tag_field && header_for_tag)
                        header_for_tag
                      elsif (c == report_label_field && groupby_label)
                        groupby_label
                      else
                        c
                      end
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

  def self.default_column_for_format(col)
    if col.start_with?('storage_allocated')
      col.ends_with?('cost') ? 'storage_allocated_cost' : 'storage_allocated_metric'
    else
      col
    end
  end

  def self.rate_column?(col)
    col.ends_with?("_rate")
  end

  private

  def relevant_fields
    @relevant_fields ||= (@options.report_cols || self.class.report_col_options.keys).to_set
  end
end # class Chargeback
