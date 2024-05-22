# Note: when changing a formatter, please consider also changing the corresponding entry in miq_formatters.js

module MiqReport::Formatting
  extend ActiveSupport::Concern

  module ClassMethods
    def get_available_formats(path, dt)
      col = path.split("-").last.to_sym
      sfx = col.to_s.split("__").last
      MiqReport::Formats.available_formats_for(col, sfx, dt)
    end
  end

  def javascript_format(col, format_name)
    format_name ||= MiqReport::Formats.default_format_for_path(col, nil)
    return nil unless format_name && format_name != :_none_

    format = MiqReport::Formats.details(format_name)
    function_name = format[:function][:name]

    options = format.merge(format[:function]).slice(
      *%i[delimiter separator precision length tz column format prefix suffix description unit])

    [function_name, options]
  end

  def formatter_by(column)
    formatter = nil
    if Chargeback.db_is_chargeback?(db)
      if db.to_s == "ChargebackContainerProject" # override format: default is mhz but cores needed for containers
        if %w[cpu_used_metric cpu_metric].include?(column)
          formatter = :cores
        end
      end

      formatter = :_none_ if Chargeback.rate_column?(column.to_s)
    end

    formatter
  end

  def format_options_by(column)
    format_options = {:column => column_to_format(column)}

    formatter = formatter_by(column)
    format_options[:format] = formatter if formatter

    if Chargeback.db_is_chargeback?(db)
      # Chargeback Reports: Add the selected currency in the assigned rate to options
      @rates_cache ||= Chargeback::RatesCache.new
      format_options[:unit] = @rates_cache.currency_for_report if @rates_cache.currency_for_report
    end

    format_options
  end

  def column_to_format(column)
    if is_numeric?(column)
      col_order[column]
    elsif db.to_s == "VimPerformanceTrend"
      if col == "limit_col_value"
        db_options[:limit_col]
      elsif col.to_s.ends_with?("_value")
        db_options[:trend_col]
      end
    elsif Chargeback.db_is_chargeback?(db)
      Chargeback.default_column_for_format(column.to_s)
    end || column
  end

  def format_attributes_for(column_formatter, col, value)
    format_attributes = if column_formatter == :_default_
                          format_from_miq_expression(col, value)
                        elsif column_formatter.kind_of?(Symbol) || column_formatter.kind_of?(String)
                          MiqReport::Formats.details(column_formatter)
                        elsif column_formatter
                          column_formatter.deep_clone # Make sure we don't taint the original
                        elsif column_formatter.nil?
                          # Look in this report object for column format
                          self.col_formats ||= []
                          idx = col_order.index(col)
                          MiqReport::Formats.details(self.col_formats[idx])
                        end

    format_attributes || format_from_miq_expression(col, value)
  end

  def format(col, value, options = {})
    return "" if value.nil?

    options = options.merge(format_options_by(col))

    column_formatter = options.delete(:format)
    return String.new(value.to_s) if column_formatter == :_none_ # Raw value was requested, do not attempt to format

    default_format_attributes = format_attributes_for(column_formatter, col, value)

    if default_format_attributes && default_format_attributes.merge!(options)[:function]
      value = apply_format_function(value, default_format_attributes.deep_clone)
    end

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
    helper_options[:unit] = options[:unit] if options.key?(:unit)
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
      val == true ? "Yes" : "No"
    when "y_n"
      val == true ? "Y" : "N"
    when "t_f"
      val == true ? "T" : "F"
    when "pass_fail"
      val == true ? "Pass" : "Fail"
    else
      val.to_s.titleize
    end
  end

  def format_datetime(val, options)
    return val unless val.kind_of?(Time) || val.kind_of?(Date)

    val = val.in_time_zone(options[:tz]) if val.kind_of?(Time) && options[:tz]
    return val if options[:format].nil?

    val.strftime(options[:format])
  end

  def format_relative_date(val, _options)
    return val unless val.kind_of?(Time) || val.kind_of?(Date) || val.kind_of?(DateTime)

    "#{ApplicationController.helpers.time_ago_in_words(val)} ago"
  end

  def format_datetime_range(val, options)
    return val if options[:format].nil?
    return val unless val.kind_of?(Time) || stime.kind_of?(Date)

    col = options[:column]
    _col, sfx = col.to_s.split("__") # The suffix (month, quarter, year) defines the range

    val = val.in_time_zone(get_time_zone("UTC"))
    if val.respond_to?(:"beginning_of_#{sfx}")
      stime = val.send(:"beginning_of_#{sfx}")
      etime = val.send(:"end_of_#{sfx}")
    else
      stime = etime = val
    end

    if options[:description].to_s.include?("Start")
      stime.strftime(options[:format])
    else
      "(#{stime.strftime(options[:format])} - #{etime.strftime(options[:format])})"
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

    names = %w[day hour minute second]

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

  private

  def format_from_miq_expression(col, value)
    @miq_exp_dt_map ||= {}
    expression_col = col_to_expression_col(col)

    unless @miq_exp_dt_map.key?(col)
      @miq_exp_dt_map[col] = MiqExpression::Target.parse(expression_col).column_type
    end
    dt = @miq_exp_dt_map[col]
    dt = value.class.to_s.downcase if dt.nil?
    dt = dt.to_sym unless dt.nil?
    MiqReport::Formats.default_format_details_for(expression_col, col, dt)
  end
end
