class Chargeback < ActsAsArModel
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
      data[key].calculate_costs(consumption, rates_to_apply)
    end
    _log.info("Calculating chargeback costs...Complete")

    [data.values]
  end

  def self.report_row_key(consumption)
    ts_key = @options.start_of_report_step(consumption.timestamp)
    if @options[:groupby_tag].present?
      classification = classification_for(consumption)
      classification_id = classification.present? ? classification.id : 'none'
      "#{classification_id}_#{ts_key}"
    else
      default_key(consumption, ts_key)
    end
  end

  def self.default_key(consumption, ts_key)
    "#{consumption.resource_id}_#{ts_key}"
  end

  def self.classification_for(consumption)
    tag = consumption.tag_names.find { |x| x.starts_with?(@options[:groupby_tag]) } # 'department/*'
    tag = tag.split('/').second unless tag.blank? # 'department/finance' -> 'finance'
    @options.tag_hash[tag]
  end

  def initialize(options, consumption)
    @options = options
    super()
    if @options[:groupby_tag].present?
      classification = self.class.classification_for(consumption)
      self.tag_name = classification.present? ? classification.description : _('<Empty>')
    else
      init_extra_fields(consumption)
    end
    self.start_date, self.end_date, self.display_range = options.report_step_range(consumption.timestamp)
    self.interval_name = options.interval
    self.chargeback_rates = ''
    self.entity ||= consumption.resource
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

  private

  def relevant_fields
    @relevant_fields ||= self.class.report_col_options.keys.to_set
  end
end # class Chargeback
