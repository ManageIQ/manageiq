# Note: when changing a formatter, please consider also changing the corresponding entry in miq_formatters.js

module MiqReport::Formatting
  extend ActiveSupport::Concern

  format_hash = YAML.load_file(ApplicationRecord::FIXTURE_DIR.join("miq_report_formats.yml"))
  FORMATS                       = format_hash[:formats].freeze
  FORMAT_DEFAULTS_AND_OVERRIDES = format_hash[:defaults_and_overrides].freeze

  module ClassMethods
    def get_available_formats(path, dt)
      col = path.split("-").last.to_sym
      sfx = col.to_s.split("__").last
      is_break_sfx = (sfx && self.is_break_suffix?(sfx))
      sub_type = FORMAT_DEFAULTS_AND_OVERRIDES[:sub_types_by_column][col]
      FORMATS.keys.inject({}) do |h, k|
        # Ignore formats that don't include suffix if the column name has a break suffix
        next(h) if is_break_sfx && (FORMATS[k][:suffixes].nil? || !FORMATS[k][:suffixes].include?(sfx.to_sym))

        if FORMATS[k][:columns] && FORMATS[k][:columns].include?(col)
          h[k] = FORMATS[k][:description]
        elsif FORMATS[k][:sub_types] && FORMATS[k][:sub_types].include?(sub_type)
          h[k] = FORMATS[k][:description]
        elsif FORMATS[k][:data_types] && FORMATS[k][:data_types].include?(dt)
          h[k] = FORMATS[k][:description]
        elsif FORMATS[k][:suffixes] && FORMATS[k][:suffixes].include?(sfx.to_sym)
          h[k] = FORMATS[k][:description]
        end
        h
      end
    end

    def get_default_format(path, dt)
      col = path.split("-").last.to_sym
      sfx = col.to_s.split("__").last
      sfx = sfx.to_sym if sfx
      sub_type = FORMAT_DEFAULTS_AND_OVERRIDES[:sub_types_by_column][col]
      FORMAT_DEFAULTS_AND_OVERRIDES[:formats_by_suffix][sfx] || FORMAT_DEFAULTS_AND_OVERRIDES[:formats_by_column][col] || FORMAT_DEFAULTS_AND_OVERRIDES[:formats_by_sub_type][sub_type] || FORMAT_DEFAULTS_AND_OVERRIDES[:formats_by_data_type][dt]
    end
  end

  def javascript_format(col, format_name)
    format_name ||= self.class.get_default_format(col, nil)
    return nil unless format_name && format_name != :_none_

    format = FORMATS[format_name]
    function_name = format[:function][:name]

    options = format.merge(format[:function]).slice(
      %i(delimiter separator precision length tz column format prefix suffix description unit))

    [function_name, options]
  end

  def format(col, value, options = {})
    if db.to_s == "VimPerformanceTrend"
      if col == "limit_col_value"
        col = db_options[:limit_col] || col
      elsif col.to_s.ends_with?("_value")
        col = db_options[:trend_col] || col
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
      expression_col = col_to_expression_col(col)
      dt = self.class.get_col_type(expression_col)
      dt = value.class.to_s.downcase.to_sym if dt.nil?
      dt = dt.to_sym unless dt.nil?
      format = FORMATS[self.class.get_default_format(expression_col, dt)]
      format = format.deep_clone if format # Make sure we don't taint the original
      format[:precision] = FORMAT_DEFAULTS_AND_OVERRIDES[:precision_by_column][col.to_sym] if format && FORMAT_DEFAULTS_AND_OVERRIDES[:precision_by_column].key?(col.to_sym)
    else
      format = format.deep_clone # Make sure we don't taint the original
    end

    options[:column] = col
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
