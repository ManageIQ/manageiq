class Chargeback < ActsAsArModel
  set_columns_hash( # Fields common to any chargeback type
    :start_date           => :datetime,
    :end_date             => :datetime,
    :interval_name        => :string,
    :display_range        => :string,
    :chargeback_rates     => :string,
    :entity               => :binary,
    :tag_name             => :string,
    :label_name           => :string,
    :fixed_compute_metric => :integer,
    :metering_used_metric => :integer,
    :metering_used_cost   => :float
  )

  def self.build_results_for_report_chargeback(options)
    _log.info("Calculating chargeback costs...")
    @options = options = ReportOptions.new_from_h(options)

    data = {}
    rates = RatesCache.new
    ConsumptionHistory.for_report(self, options) do |consumption|
      rates_to_apply = rates.get(consumption)
      key = report_row_key(consumption)
      data[key] ||= new(options, consumption)

      chargeback_rates = data[key]["chargeback_rates"].split(', ') + rates_to_apply.collect(&:description)
      data[key]["chargeback_rates"] = chargeback_rates.uniq.join(', ')

      # we are getting hash with metrics and costs for metrics defined for chargeback

      if ENV['CHARGIO']
        data[key].chargio_calculate_costs(consumption, rates_to_apply)
      else
        data[key].calculate_costs(consumption, rates_to_apply)
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

  def initialize(options, consumption)
    @options = options
    super()
    if @options[:groupby_tag].present?
      classification = @options.classification_for(consumption)
      self.tag_name = classification.present? ? classification.description : _('<Empty>')
    elsif @options[:groupby_label].present?
      label_value = self.class.groupby_label_value(consumption, options[:groupby_label])
      self.label_name = label_value.present? ? label_value : _('<Empty>')
    else
      init_extra_fields(consumption)
    end
    self.start_date, self.end_date, self.display_range = options.report_step_range(consumption.timestamp)
    self.interval_name = options.interval
    self.chargeback_rates = ''
    self.entity ||= consumption.resource
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

  # add filter to showback rate
  # using report monthly/weekly/daily
  # use daily/hourly/monthly in  showback charge
  # map new result value to report engine
  # rewrite with using tiers


  def chargio_calculate_costs(consumption, rates)
    self.fixed_compute_metric = consumption.chargeback_fields_present if consumption.chargeback_fields_present

    rates.each do |rate| # ChargebackRate

      plan = ManageIQ::Consumption::ShowbackPricePlan.find_or_create_by(:description   => rate.description,
                                                                        :name          => rate.description,
                                                                        :resource      => MiqEnterprise.first
      )

      rate.rate_details_relevant_to(relevant_fields).each do |r| # ChargebackRateDetail
        r.populate_showback_rate(plan, r, showback_category)

        measure = r.chargeable_field.showback_measure
        dimension, unit, calculation = r.chargeable_field.showback_dimension

        value = r.chargeable_field.fixed? ? 1.0 : consumption.avg(r.chargeable_field.metric)

        result = plan.calculate_total_cost_input(resource_type: showback_category,
                                                 data: {measure => {dimension =>value } },
                                                 start_time: consumption.instance_variable_get("@start_time"),
                                                 end_time: consumption.instance_variable_get("@end_time"),
                                                 cycle_duration: 2678400 # 1.month, report monthly, weekly, daily
        )

        puts "CHARGIO COST: #{r.chargeable_field.metric}: #{result.to_f}"

        r.charge(relevant_fields, consumption, @options).each do |field, value| # this cycle is getting metric, cost and total cost
          next unless self.class.attribute_names.include?(field)
          self[field] = (self[field] || 0) + value
          puts "#{field}: #{self[field].to_f}"
        end
        puts "---"
        plan.showback_rates.destroy_all
        plan.reload
      end

    end

  end

  def calculate_costs(consumption, rates)
    self.fixed_compute_metric  = consumption.chargeback_fields_present if consumption.chargeback_fields_present

    rates.each do |rate|
      rate.rate_details_relevant_to(relevant_fields).each do |r|
        r.charge(relevant_fields, consumption, @options).each do |field, value|
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

  def self.report_label_field
    "label_name"
  end

  def self.set_chargeback_report_options(rpt, group_by, header_for_tag, groupby_label, tz)
    rpt.cols = %w(start_date display_range)

    static_cols       = group_by == "project" ? report_static_cols - ["image_name"] : report_static_cols
    static_cols       = group_by == "tag" ? [report_tag_field] : static_cols
    static_cols       = group_by == "label" ? [report_label_field] : static_cols
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

  private

  def relevant_fields
    @relevant_fields ||= (@options.report_cols || self.class.report_col_options.keys).to_set
  end
end # class Chargeback
