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
    if self.db_options[:interval] == "daily"
      results = []

      includes = self.include.blank? ? [] : self.include.keys
      associations = includes.is_a?(Hash) ? includes.keys : Array(includes)
      only_cols = [self.db_options[:limit_col], self.db_options[:trend_col]].compact

      start_time, end_time = Metric::Helper.get_time_range_from_offset(self.db_options[:start_offset], self.db_options[:end_offset], :tz => self.tz)
      trend_klass = self.db_options[:trend_db].is_a?(Class) ? self.db_options[:trend_db] : Object.const_get(self.db_options[:trend_db])

      time_range_cond = ["timestamp BETWEEN ? AND ?", start_time, end_time]
      recs = VimPerformanceDaily.find(:all,
        :conditions  => VimPerformanceDaily.merge_conditions(where_clause, time_range_cond),
        :include     => includes,
        :ext_options => {:class => trend_klass, :only_cols => only_cols, :reflections => associations, :tz => self.tz, :time_profile => self.time_profile}
      )
      results, attrs = Rbac.search(:targets => recs, :class => self.db_options[:trend_db], :filter => self.db_options[:trend_filter], :results_format => :objects, :userid => options[:userid], :miq_group_id => options[:miq_group_id]) unless recs.empty?
    else
      start_time = Time.now.utc -  self.db_options[:start_offset].seconds
      end_time   =  self.db_options[:end_offset].nil? ? Time.now.utc : Time.now.utc -  self.db_options[:end_offset].seconds

      # Search and filter performance data
      trend_klass = self.db_options[:trend_db].is_a?(Class) ? self.db_options[:trend_db] : Object.const_get(self.db_options[:trend_db])
      recs = trend_klass.find_all_by_interval_and_time_range(
        'hourly',
        start_time,
        end_time,
        :all,
        :conditions => where_clause
      )
      results, attrs = Rbac.search(:targets => recs, :class => self.db_options[:trend_db], :filter => self.db_options[:trend_filter], :results_format => :objects, :userid => options[:userid], :miq_group_id => options[:miq_group_id]) unless results.empty?
    end

    klass = db.is_a?(Class) ? db : Object.const_get(db)
    self.title = klass.report_title(self.db_options)
    self.cols, self.headers = klass.report_cols(self.db_options)
    options[:only] ||= (self.cols + self.build_cols_from_include(self.include) + ['id']).uniq

    # Build and filter trend data from performance data
    self.build_apply_time_profile(results)
    results = klass.build(results, self.db_options)
    results, attrs = Rbac.search(:targets => results, :class => self.db, :filter => self.conditions, :results_format => :objects, :limit => options[:limit], :userid => options[:userid], :miq_group_id => options[:miq_group_id]) unless results.empty?

    return [results]
  end

  def build_calculate_trend_point(rec, col)
    return nil unless rec.respond_to?(CHART_X_AXIS_COLUMN)
    return nil if @trend_data[col][:slope].nil?
    return nil if rec.respond_to?(:inside_time_profile) && rec.inside_time_profile == false

    begin
      val = MiqStats.solve_for_y(rec.send(CHART_X_AXIS_COLUMN_ADJUSTED).to_i, @trend_data[col][:slope], @trend_data[col][:yint])
      return val > 0 ? val : 0
    rescue ZeroDivisionError => err
      return nil
    end
  end

  def build_trend_data(recs)
    return if self.cols.nil?
    return if recs.blank?

    @trend_data = {}
    recs.sort!{|a,b| a.send(CHART_X_AXIS_COLUMN) <=> b.send(CHART_X_AXIS_COLUMN)} if recs.first.respond_to?(CHART_X_AXIS_COLUMN)

    self.cols.each {|c|
      next unless self.class.is_trend_column?(c)
      @trend_data[c] = {}

      y_array, x_array = recs.inject([]) do |arr,r|
        arr[0] ||= []; arr[1] ||= []
        next(arr) unless  r.respond_to?(CHART_X_AXIS_COLUMN) && r.respond_to?(c[6..-1])
        if r.respond_to?(:inside_time_profile) && r.inside_time_profile == false
          $log.debug("MIQ(MiqReport.build_trend_data) Timestamp: [#{r.timestamp}] is outside of time profile: [#{self.time_profile.description}]")
          next(arr)
        end
        arr[0] << r.send(c[6..-1]).to_f
        # arr[1] << r.send(CHART_X_AXIS_COLUMN).to_i # Calculate normal way by using the integer value of the timestamp
        r.send("#{CHART_X_AXIS_COLUMN_ADJUSTED}=", (recs.first.send(CHART_X_AXIS_COLUMN).to_i + arr[1].length.days.to_i))
        arr[1] << r.send(CHART_X_AXIS_COLUMN_ADJUSTED).to_i # Caculate by using the number of days out from the first timestamp
        arr
      end

      begin
        slope_arr = MiqStats.slope(x_array, y_array)
      rescue ZeroDivisionError
        slope_arr = []
      rescue => err
        $log.warn("MIQ(MiqReport.build_trend_data) #{err.message}, calculating slope")
        slope_arr = []
      end
      @trend_data[c][:slope], @trend_data[c][:yint], @trend_data[c][:corr] = slope_arr
    }
  end

  def build_trend_limits(recs)
    return if self.cols.nil? || @trend_data.blank?
    self.cols.each do |c|
      #XXX: TODO: Hardcoding column names for now until we have more time to extend the model and allow defining these in YAML
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

      limit = recs.sort {|a,b| a.timestamp <=> b.timestamp}.last.send(c) unless recs.empty?

      attributes.each do |attribute|
        trend_data_key = CHART_TREND_COLUMN_PREFIX + attribute.to_s

        @extras[:trend]["#{trend_data_key}|#{c}"] = self.calc_value_at_target(limit, trend_data_key, @trend_data)
      end
    end
  end

  def calc_value_at_target(limit, trend_data_key, trend_data)
    unknown = "Trending Down"
    if limit.nil? || trend_data[trend_data_key].nil? || trend_data[trend_data_key][:slope].nil? || trend_data[trend_data_key][:yint].nil? || trend_data[trend_data_key][:slope] <= 0 # can't project with a negative slope value
      return unknown
    else
      begin
        result = MiqStats.solve_for_x(limit, trend_data[trend_data_key][:slope], trend_data[trend_data_key][:yint])
        if result <= 1.year.from_now.to_i
          if Time.at(result).utc <= Time.now.utc
            return Time.at(result).utc.strftime("%m/%d/%Y")
          else
            return "#{((Time.at(result).utc - Time.now.utc) / 1.day).round} days, on #{Time.at(result).utc.strftime("%m/%d/%Y")} (#{self.get_time_zone("UTC")})"
          end
        else
          return "after 1 year"
        end
      rescue RangeError
        return unknown
      rescue => err
        $log.warn("MIQ(MiqReport-calc_value_at_target) #{err.message}, calculating trend limit for column: [#{trend_data_key}]")
        return unknown
      end
    end
  end

end
