class VimPerformanceTrend < ActsAsArModel
  set_columns_hash(
    :resource_name      => :string,
    :resource_id        => :integer,
    :resource_type      => :string,
    :trend_col_name     => :string,
    :start_trend_value  => :integer,
    :end_trend_value    => :float,
    :max_trend_value    => :float,
    :min_trend_value    => :float,
    :count_of_trend     => :integer,
    :direction_of_trend => :string,
    :slope              => :float,
    :limit_col_value    => :datetime,
    :limit_pct_value_1  => :datetime,
    :limit_pct_value_2  => :datetime,
    :limit_pct_value_3  => :datetime,
    :limit_pct_value_4  => :datetime,
    :limit_pct_value_5  => :datetime
  )

  CHART_X_AXIS_COL = :timestamp

  def self.vms_by_category(options)
    model, interval = options[:interval_name] == "hourly" ? [MetricRollup, 1.hour] : [VimPerformanceDaily, 1.day]
    rows = model.where(:timestamp             => options[:timestamp],
                       :capture_interval_name => options[:interval_name],
                       :resource_type         => "VmOrTemplate")
                .for_tag_names(options[:group_by_category], options[:group_by_tag])
    [build(rows.to_a, options), interval]
  end

  def self.build(perfs, options)
    # options = {
    #   :trend_col      => "max_cpu_usagemhz_rate_average",
    #   :limit_col      => "max_derived_cpu_available",
    #   :limit_val      => 4096,
    #   :target_pcts    => [70, 80, 90, 100],
    # }

    options[:limit_col] ? options[:limit_col] : "limit"

    # group data by resource name
    grouped_objs = perfs.inject({}) do |h, o|
      name = o.resource.name if o.resource
      h[name] ||= []
      h[name].push(o)
      h
    end

    # calculate trend data for each group
    trend_data = grouped_objs.inject({}) do |h, group|
      name, olist = group
      h[name] = build_trend_data(options[:trend_col], olist)
      h
    end

    # build table data
    table_data = grouped_objs.inject([]) do |arr, group|
      name, olist = group
      olist.sort! { |a, b| a.timestamp <=> b.timestamp }
      limit   = olist.last.send(options[:limit_col]) if options[:limit_col]
      limit ||= options[:limit_val].to_f

      row = {}
      row[:resource_name] = name
      row[:trend_col_name] = options[:trend_col]

      # calculate values at limit percents
      options[:target_pcts].each do |pct|
        col_name = "limit_pct_value_#{options[:target_pcts].index(pct) + 1}"
        pct_of_limit = (limit * pct * 0.01)
        row[col_name] = calc_value_at_target(pct_of_limit, trend_data[name])
        if row[col_name].nil?
          row[col_name] = "Unknown"
        elsif row[col_name] < Time.now.utc
          row[col_name] = "--------------"
        elsif row[col_name] > Time.now.utc + 2.years
          row[col_name] = "Over 2 Years"
        else
          row[col_name] = row[col_name].strftime("%m/%d/%Y")
        end
      end

      # Need to exclude records that are outside time profile when calculating range min and max values
      olist_in_time_profile = olist.find_all do |r|
        if r.respond_to?(:inside_time_profile)
          r.inside_time_profile != false
        else
          true
        end
      end

      # calculate min and max
      ordered_by_trend_col = olist_in_time_profile.sort do |a, b|
        a_val = a.send(options[:trend_col]) || 0
        b_val = b.send(options[:trend_col]) || 0
        a_val <=> b_val
      end
      row[:min_trend_value] = ordered_by_trend_col.first.send(options[:trend_col])
      row[:max_trend_value] = ordered_by_trend_col.last.send(options[:trend_col])

      # calculate start/end trend values
      ordered_by_timestamp  = olist_in_time_profile.sort_by(&:timestamp)
      row[:start_trend_value] = ordered_by_timestamp.first.send(options[:trend_col])
      row[:end_trend_value]   = ordered_by_timestamp.last.send(options[:trend_col])

      # slope
      row[:slope] = trend_data[name][:slope]
      row[:slope] = options[:interval] == "daily" ? (row[:slope] * 1.day) : (row[:slope] * 1.hour) unless row[:slope].nil?

      # trend count
      row[:count_of_trend] = trend_data[name][:count]

      # trend direction
      row[:direction_of_trend] = if row[:slope].nil?
                                   nil
                                 elsif row[:slope] > 0
                                   "Up"
                                 elsif row[:slope] < 0
                                   "Down"
                                 else
                                   "Flat"
                                 end

      # value of limit column
      row[:limit_col_value] = limit if options[:limit_col]

      # TODO:
      # attributes hash is the same for all rows created yet the individual attributes are correct when accessed individually
      arr.push(new(row))
    end

    table_data
  end

  def self.calc_value_at_target(limit, trend_data)
    if trend_data.nil? || trend_data[:slope].nil?
      return nil
    else
      begin
        result = Math.slope_x_intercept(limit, trend_data[:slope], trend_data[:yint])
        return Time.at(result).utc
      rescue RangeError
        return nil
      rescue => err
        _log.warn("#{err.message}, calculating trend limit for limit=#{limit}, trend_data=#{trend_data.inspect}, intermediate=#{result.inspect}")
        return nil
      end
    end
  end

  def self.build_trend_data(col, recs)
    trend_data = {}

    coordinates = recs.collect do |r|
      next unless r.respond_to?(CHART_X_AXIS_COL) && r.respond_to?(col)
      [r.send(CHART_X_AXIS_COL).to_i, r.send(col).to_f]
    end.compact

    trend_data[:count] = coordinates.length
    trend_data[:slope], trend_data[:yint], trend_data[:corr] =
      begin
        Math.linear_regression(*coordinates)
      rescue StandardError => err
        _log.warn("#{err.message}, calculating slope") unless err.kind_of?(ZeroDivisionError)
        nil
      end

    trend_data
  end

  TREND_COLS = {
    :VmPerformance         => {
      :cpu_usagemhz_rate_average => {},
      :cpu_usage_rate_average    => {},
      :disk_usage_rate_average   => {},
      :net_usage_rate_average    => {},
      :derived_memory_used       => {:limit_cols => ["derived_memory_available"]}
    },
    :HostPerformance       => {
      :cpu_usagemhz_rate_average => {:limit_cols => ["derived_cpu_available", "derived_cpu_reserved"]},
      :cpu_usage_rate_average    => {},
      :disk_usage_rate_average   => {},
      :net_usage_rate_average    => {},
      :derived_memory_used       => {:limit_cols => ["derived_memory_available", "derived_memory_reserved"]}
    },
    :EmsClusterPerformance => {
      :cpu_usagemhz_rate_average => {:limit_cols => ["derived_cpu_available", "derived_cpu_reserved"]},
      :cpu_usage_rate_average    => {},
      :disk_usage_rate_average   => {},
      :net_usage_rate_average    => {},
      :derived_memory_used       => {:limit_cols => ["derived_memory_available", "derived_memory_reserved"]}
    },
    :ExtManagementSystemPerformance => {
      :cpu_usagemhz_rate_average => {:limit_cols => %w(derived_cpu_available derived_cpu_reserved)},
      :cpu_usage_rate_average    => {},
      :disk_usage_rate_average   => {},
      :net_usage_rate_average    => {},
      :derived_memory_used       => {:limit_cols => %w(derived_memory_available derived_memory_reserved)}
    },
    :StoragePerformance    => {
      :derived_storage_free   => {:limit_cols => ["derived_storage_total"]},
      :v_derived_storage_used => {:limit_cols => ["derived_storage_total"]}
    }
  }

  def self.trend_model_details(interval)
    result = []
    TREND_COLS.each_key do |db|
      friendly_db = Dictionary.gettext(db.to_s, :type => "model")
      TREND_COLS[db].each_key do |col|
        cols = interval == "daily" ? ["min_#{col}", col, "max_#{col}"] : [col] # add in min and max if daily
        cols.each { |c| result.push([[friendly_db, Dictionary.gettext([db, c.to_s].join("."), :type => "column")].join(" : "), [db, c.to_s].join("-")]) }
      end
    end
    result
  end

  def self.trend_limit_cols(db, col, interval)
    col = col.starts_with?("min_", "max_") ? col[4..-1] : col
    return [] unless TREND_COLS[db.to_sym]
    return [] unless TREND_COLS[db.to_sym][col.to_sym]
    return [] unless TREND_COLS[db.to_sym][col.to_sym][:limit_cols]
    TREND_COLS[db.to_sym][col.to_sym][:limit_cols].inject([]) do |arr, col|
      cols = interval == "daily" ? ["max_#{col}"] : [col] # add in max if daily
      cols.each { |c| arr.push([Dictionary.gettext([db, c.to_s].join("."), :type => "column"), c]) }
      arr
    end
  end

  def self.report_cols(options)
    col_headers = []
    col_order = [
      "resource_name",
      "direction_of_trend",
      "start_trend_value",
      "end_trend_value",
      "max_trend_value",
      "min_trend_value",
      "count_of_trend",
      "slope"
    ]
    col_order.each do |c|
      if c.ends_with?("_trend_value")
        col_headers << "#{Dictionary.gettext([options[:trend_db], c].join("."), :type => "column", :notfound => :titleize)} - #{Dictionary.gettext([options[:trend_db], options[:trend_col]].join("."), :type => "column", :notfound => :titleize)}"
      else
        col_headers << Dictionary.gettext([options[:trend_db], c].join("."), :type => "column", :notfound => :titleize)
      end
    end

    if options[:limit_col]
      col_order << "limit_col_value"
      col_headers << Dictionary.gettext([options[:trend_db], options[:limit_col]].join("."), :type => "column", :notfound => :titleize)
    end

    options[:target_pcts].each do |c|
      col_order << "limit_pct_value_#{options[:target_pcts].index(c) + 1}"
      col_headers << "#{c}%"
    end

    return col_order, col_headers
  end

  def self.report_title(options)
    # Host Daily Max CPU Trend towards Available CPU (3/1/09 through 4/1/09)
    # Host Daily Avg Network I/O Trend towards 200 KBps (3/1/09 through 4/1/09)
    title =  options[:interval].titleize
    title += " " + Dictionary.gettext(options[:trend_db], :type => :model)
    title += " " + Dictionary.gettext([options[:trend_db], options[:trend_col]].join("."), :type => :column)
    title += " Trend towards "
    title += options[:limit_col] ? Dictionary.gettext([options[:trend_db], options[:limit_col]].join("."), :type => :column) : options[:limit_val].to_s

    start_time = options[:start_offset].seconds.ago.utc
    end_time   = options[:end_offset].nil? ? Time.now.utc : options[:end_offset].seconds.ago.utc
    time_format = "%m/%d/%y"
    title += " (#{start_time.strftime(time_format)} through #{end_time.strftime(time_format)})"

    title
  end

  def self.display_name(number = 1)
    n_('Performance Trend', 'Performance Trends', number)
  end
end
