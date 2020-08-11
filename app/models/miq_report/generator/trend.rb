module MiqReport::Generator::Trend
  extend ActiveSupport::Concern

  CHART_X_AXIS_COLUMN          = :timestamp # this will need to be defined in the report object when we want to calculate trend on data other than performance
  CHART_X_AXIS_COLUMN_ADJUSTED = :time_profile_adjusted_timestamp
  CHART_TREND_COLUMN_PREFIX    = "trend_"

  module ClassMethods
    def is_trend_column?(column)
      column.starts_with?(CHART_TREND_COLUMN_PREFIX)
    end
  end

  def build_results_for_report_trend(options)
    # self.db_options = {
    #   :rpt_type       => "trend",
    #   :interval       => "daily",
    #   :start_offset   => 2.days.ago.utc.to_i,
    #   :end_offset     => 0,
    #   :trend_col      => "max_cpu_usagemhz_rate_average",
    #   :limit_col      => "max_derived_cpu_available",
    #   :limit_val      => 4096,
    #   :target_pcts    => [70, 80, 90, 100]
    #   :trend_filter   => MiqExpression#object
    #   :trend_db       => VmPerformance
    # }
    trend_klass = db_options[:trend_db]
    trend_klass = Object.const_get(trend_klass) unless trend_klass.kind_of?(Class)
    if db_options[:interval] == "daily"
      includes = include.blank? ? [] : include.keys

      time_range = Metric::Helper.time_range_from_offset("daily", db_options[:start_offset], db_options[:end_offset], tz)
      recs = Metric::Helper.find_for_interval_name("daily", time_profile || tz, trend_klass)
                           .where(where_clause).where(:timestamp => time_range).includes(includes)
    else
      time_range = Metric::Helper.time_range_from_offset('hourly', db_options[:start_offset], db_options[:end_offset])

      # Search and filter performance data
      recs = trend_klass.with_interval_and_time_range('hourly', time_range).where(where_clause)
    end
    results = Rbac.filtered(recs, :class        => db_options[:trend_db],
                                  :filter       => db_options[:trend_filter],
                                  :userid       => options[:userid],
                                  :miq_group_id => options[:miq_group_id])
    self.title = db_klass.report_title(db_options)
    self.cols, self.headers = db_klass.report_cols(db_options)
    options[:only] ||= cols_for_report

    # Build and filter trend data from performance data
    build_apply_time_profile(results)
    results = db_klass.build(results, db_options)

    if conditions
      tz = User.lookup_by_userid(options[:userid]).get_timezone if options[:userid]
      results = results.reject { |obj| conditions.lenient_evaluate(obj, tz) }
    end
    results = results[0...options[:limit]] if options[:limit]
    [results]
  end

  def build_calculate_trend_point(rec, col)
    return nil unless rec.respond_to?(CHART_X_AXIS_COLUMN)
    return nil if @trend_data[col][:slope].nil?
    return nil if rec.respond_to?(:inside_time_profile) && rec.inside_time_profile == false

    begin
      val = Math.slope_y_intercept(rec.send(CHART_X_AXIS_COLUMN_ADJUSTED).to_i, @trend_data[col][:slope], @trend_data[col][:yint])
      return val > 0 ? val : 0
    rescue ZeroDivisionError
      return nil
    end
  end

  def build_trend_data(recs)
    return if cols.nil?
    return if recs.blank?

    @trend_data = {}
    recs.sort! { |a, b| a.send(CHART_X_AXIS_COLUMN) <=> b.send(CHART_X_AXIS_COLUMN) } if recs.first.respond_to?(CHART_X_AXIS_COLUMN)

    cols.each do |c|
      next unless self.class.is_trend_column?(c)
      @trend_data[c] = {}

      coordinates = recs.each_with_object([]) do |r, arr|
        next unless r.respond_to?(CHART_X_AXIS_COLUMN) && r.respond_to?(c[6..-1])
        if r.respond_to?(:inside_time_profile) && r.inside_time_profile == false
          _log.debug("Timestamp: [#{r.timestamp}] is outside of time profile: [#{time_profile.description}]")
          next
        end
        y = r.send(c[6..-1]).to_f
        # y = r.send(CHART_X_AXIS_COLUMN).to_i # Calculate normal way by using the integer value of the timestamp
        r.send("#{CHART_X_AXIS_COLUMN_ADJUSTED}=", (recs.first.send(CHART_X_AXIS_COLUMN).to_i + arr.length.days.to_i))
        x = r.send(CHART_X_AXIS_COLUMN_ADJUSTED).to_i # Calculate by using the number of days out from the first timestamp
        arr << [x, y]
      end

      @trend_data[c][:slope], @trend_data[c][:yint], @trend_data[c][:corr] =
        begin
          Math.linear_regression(*coordinates)
        rescue StandardError => err
          _log.warn("#{err.message}, calculating slope") unless err.kind_of?(ZeroDivisionError)
          nil
        end
    end
  end

  def build_trend_limits(recs)
    return if cols.nil? || @trend_data.blank?
    cols.each do |c|
      # XXX: TODO: Hardcoding column names for now until we have more time to extend the model and allow defining these in YAML
      case c.to_sym
      when :max_derived_memory_available
        attributes = [:max_derived_memory_used, :derived_memory_used]
      when :max_derived_memory_reserved
        attributes = [:max_derived_memory_used, :derived_memory_used]
      when :max_derived_cpu_available
        attributes = [:max_cpu_usagemhz_rate_average, :cpu_usagemhz_rate_average]
      when :max_derived_cpu_reserved
        attributes = [:max_cpu_usagemhz_rate_average, :cpu_usagemhz_rate_average]
      when :derived_storage_total
        attributes = [:max_v_derived_storage_used, :v_derived_storage_used]
      else
        next
      end

      @extras ||= {}
      @extras[:trend] ||= {}

      limit = recs.max_by(&:timestamp).send(c) unless recs.empty?

      attributes.each do |attribute|
        trend_data_key = CHART_TREND_COLUMN_PREFIX + attribute.to_s

        @extras[:trend]["#{trend_data_key}|#{c}"] = calc_value_at_target(limit, trend_data_key, @trend_data)
      end
    end
  end

  def calc_value_at_target(limit, trend_data_key, trend_data)
    unknown = _("Trending Down")
    if limit.nil? || trend_data[trend_data_key].nil? || trend_data[trend_data_key][:slope].nil? || trend_data[trend_data_key][:yint].nil? || trend_data[trend_data_key][:slope] <= 0 # can't project with a negative slope value
      return unknown
    else
      begin
        result = Math.slope_x_intercept(limit, trend_data[trend_data_key][:slope], trend_data[trend_data_key][:yint])
        if result <= 1.year.from_now.to_i
          if Time.at(result).utc <= Time.now.utc
            return Time.at(result).utc.strftime("%m/%d/%Y")
          else
            return "#{((Time.at(result).utc - Time.now.utc) / 1.day).round} days, on #{Time.at(result).utc.strftime("%m/%d/%Y")} (#{get_time_zone("UTC")})"
          end
        else
          return "after 1 year"
        end
      rescue RangeError
        return unknown
      rescue => err
        _log.warn("#{err.message}, calculating trend limit for column: [#{trend_data_key}]")
        return unknown
      end
    end
  end
end
