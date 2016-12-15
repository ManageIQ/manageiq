# Note: when changing a formatter, please consider also changing the corresponding entry in miq_formatters.js

module MiqReport::Formatting
  extend ActiveSupport::Concern
  FORMATS = MiqReportFormats::FORMATS

  module ClassMethods
    def get_available_formats(path, dt)
      col = path.split("-").last.to_sym
      sfx = col.to_s.split("__").last
      MiqReportFormats.available_formats_for(col, sfx, dt)
    end

    def get_default_format(path, dt)
      col = path.split("-").last.to_sym
      sfx = col.to_s.split("__").last.try(:to_sym)
      MiqReportFormats.default_format_for(col, sfx, dt)
    end
  end

  def javascript_format(col, format_name)
    format_name ||= self.class.get_default_format(col, nil)
    return nil unless format_name && format_name != :_none_

    format = FORMATS[format_name]
    function_name = format[:function][:name]

    options = format.merge(format[:function]).slice(
      *%i(delimiter separator precision length tz column format prefix suffix description unit))

    [function_name, options]
  end

  def format(col, value, options = {})
    if db.to_s == "VimPerformanceTrend"
      if col == "limit_col_value"
        col = db_options[:limit_col] || col
      elsif col.to_s.ends_with?("_value")
        col = db_options[:trend_col] || col
      end
    elsif db.to_s == "ChargebackContainerProject" # override format: default is mhz but cores needed for containers
      if col == "cpu_used_metric" || col == "cpu_metric"
        options[:format] = :cores
      end
    end
    format = options.delete(:format)
    return "" if value.nil?
    return value.to_s if format == :_none_ # Raw value was requested, do not attempt to format

    # Format name passed in as a symbol or string
    format = FORMATS[format.to_sym] if (format.kind_of?(Symbol) || format.kind_of?(String)) && format != :_default_

    # Look in this report object for column format
    self.col_formats ||= []
    if format.nil?
      idx = col.kind_of?(String) ? col_order.index(col) : col
      if idx
        col = col_order[idx]
        format = FORMATS[self.col_formats[idx]]
      end
    end

    # Use default format for column stil nil
    if format.nil? || format == :_default_
      dt = MiqExpression.get_col_type(col_to_expression_col(col))
      dt = value.class.to_s.downcase.to_sym if dt.nil?
      dt = dt.to_sym unless dt.nil?
      sfx = col.to_s.split('__').last.try(:to_sym)
      format = MiqReportFormats.default_format_details_for(col, sfx, dt)
    else
      format = format.deep_clone # Make sure we don't taint the original
    end

    options[:column] = col

    # Chargeback Reports: Add the selected currency in the assigned rate to options
    if Chargeback.db_is_chargeback?(db)
      compute_selected_rate = ChargebackRate.get_assignments(:compute)[0]
      storage_selected_rate = ChargebackRate.get_assignments(:storage)[0]
      selected_rate = compute_selected_rate.nil? ? storage_selected_rate : compute_selected_rate
      options[:unit] = selected_rate[:cb_rate].chargeback_rate_details[0].detail_currency.symbol unless selected_rate.nil?
    end

    format.merge!(options) if format # Merge additional options that were passed in as overrides
    value = apply_format_function(value, format) if format && !format[:function].nil?

    String.new(value.to_s) # Generate value as a string in case it is a SafeBuffer
  end

  def apply_format_precision(value, precision)
    return value if precision.nil? || !(value.kind_of?(Integer) || value.kind_of?(Float))
    Kernel.format("%.#{precision}f", value)
  end

  def apply_format_function(value, options = {})
    function = options.delete(:function)
    method = "format_#{function[:name]}"
    raise _("Unknown format function '%{name}'") % {:name => function[:name]} unless respond_to?(method)

    send(method, value, function.merge(options))
  end

  def apply_prefix_and_suffix(val, options)
    val = options[:prefix] + val if options[:prefix]
    val += options[:suffix] if options[:suffix]

    val
  end

  def format_number_with_delimiter(val, options = {})
    helper_options = {}
    helper_options[:delimiter] = options[:delimiter] if options.key?(:delimiter)
    helper_options[:separator] = options[:separator] if options.key?(:separator)
    val = apply_format_precision(val, options[:precision])
    val = ApplicationController.helpers.number_with_delimiter(val, helper_options)
    apply_prefix_and_suffix(val, options)
  end

  def format_currency_with_delimiter(val, options = {})
    helper_options = {}
    helper_options[:delimiter] = options[:delimiter] if options.key?(:delimiter)
    helper_options[:separator] = options[:separator] if options.key?(:separator)
    helper_options[:unit] = options [:unit] if options.key?(:unit)
    val = apply_format_precision(val, options[:precision])
    val = ApplicationController.helpers.number_to_currency(val, helper_options)
    apply_prefix_and_suffix(val, options)
  end

  def format_bytes_to_human_size(val, options = {})
    helper_options = {}
    helper_options[:precision] = options[:precision] || 0  # Precision of 0 returns the significant digits
    val = ApplicationController.helpers.number_to_human_size(val, helper_options)
    apply_prefix_and_suffix(val, options)
  end

  def format_kbytes_to_human_size(val, options = {})
    format_bytes_to_human_size(val * 1.0.kilobyte, options)
  end

  def format_mbytes_to_human_size(val, options = {})
    format_bytes_to_human_size(val * 1.0.megabyte, options)
  end

  def format_gbytes_to_human_size(val, options = {})
    format_bytes_to_human_size(val * 1.0.gigabyte, options)
  end

  def format_mhz_to_human_size(val, options = {})
    val = ApplicationController.helpers.mhz_to_human_size(val, options[:precision])
    apply_prefix_and_suffix(val, options)
  end

  def format_boolean(val, options = {})
    return val.to_s.titleize if options.blank?
    return val.to_s.titleize unless val.kind_of?(TrueClass) || val.kind_of?(FalseClass)

    case options[:format]
    when "yes_no"
      return val == true ? "Yes" : "No"
    when "y_n"
      return val == true ? "Y" : "N"
    when "t_f"
      return val == true ? "T" : "F"
    when "pass_fail"
      return val == true ? "Pass" : "Fail"
    else
      return val.to_s.titleize
    end
  end

  def format_datetime(val, options)
    return val unless val.kind_of?(Time) || val.kind_of?(Date)

    val = val.in_time_zone(options[:tz]) if val.kind_of?(Time) && options[:tz]
    return val if options[:format].nil?
    val.strftime(options[:format])
  end

  def format_datetime_range(val, options)
    return val if options[:format].nil?
    return val unless val.kind_of?(Time) || stime.kind_of?(Date)

    col = options[:column]
    col, sfx = col.to_s.split("__") # The suffix (month, quarter, year) defines the range

    val = val.in_time_zone(get_time_zone("UTC"))
    if val.respond_to?("beginning_of_#{sfx}")
      stime = val.send("beginning_of_#{sfx}")
      etime = val.send("end_of_#{sfx}")
    else
      stime = etime = val
    end

    if options[:description].to_s.include?("Start")
      return stime.strftime(options[:format])
    else
      return "(#{stime.strftime(options[:format])} - #{etime.strftime(options[:format])})"
    end
  end

  def format_set(val, options)
    return val unless val.kind_of?(Array)
    options[:delimiter] ||= ", "
    val.join(options[:delimiter])
  end

  def format_datetime_ordinal(val, options)
    val = format_datetime(val, options)
    format_number_ordinal(val, options)
  end

  def format_number_ordinal(val, _options)
    val.to_i.ordinalize
  end

  def format_elapsed_time_human(val, _options)
    val = val.to_i

    names = %w(day hour minute second)
    arr = []

    days    = (val / 86400)
    hours   = (val / 3600) - (days * 24)
    minutes = (val / 60) - (hours * 60) - (days * 1440)
    seconds = (val % 60)

    arr = [days, hours, minutes, seconds]
    return if arr.all? { |a| a == 0 }

    sidx = arr.index { |a| a > 0 }
    values = arr[sidx..(sidx + 1)]
    result = ''
    sep    = ''
    values.each_index do |i|
      sfx = names[sidx + i]
      sfx += "s" if values[i] > 1 || values[i] == 0
      result = result + sep + "#{values[i]} #{sfx}"
      sep = ", "
    end

    result
  end

  def format_string_truncate(val, options = {})
    result = val.to_s
    result.length > options[:length] ? result[0..(options[:length] - 1)] + "..." : val
  end

  def format_large_number_to_exponential_form(val, _options = {})
    return val if val.to_f < 1.0e+15
    val.to_f.to_s
  end

  def format_model_name(val, _options = {})
    ui_lookup(:model => val)
  end
end
