class VimUsage < ActsAsArModel
  set_columns_hash(
    :resource_name                => :string,
    :resource_id                  => :integer,
    :derived_vm_used_disk_storage => {:type => :float, :daily_pfx => "max"},
    :cpu_usagemhz_rate_average    => :float,
    :derived_memory_used          => {:type => :float, :daily_pfx => "max"},
    :disk_usage_rate_average      => :float,
    :net_usage_rate_average       => :float

    # :derived_storage_used_managed => {:type => :float, :daily_pfx => "max"},
    # :cpu_usagemhz_rate_average    => {:type => :float, :mult => 180},
    # :disk_usage_rate_average      => {:type => :float, :mult => 1.hour},
    # :net_usage_rate_average       => {:type => :float, :mult => 1.hour}
  )

  def self.vms_by_category(options)
    if options[:interval_name] == "daily"
      model, interval = [VimPerformanceDaily, 1.day]
      ts = options[:timestamp].to_time
      cond = [
        "(timestamp >= ? and timestamp < ?) and resource_type = ? and tag_names like ?",
        ts,
        ts + interval,
        "VmOrTemplate",
        "%" + [options[:group_by_category], options[:group_by_tag]].join("/") + "%"
      ]
    else
      klass, meth = Metric::Helper.class_and_association_for_interval_name(options[:interval_name])
      model, interval = [klass, 1.hour]
      cond = [
        "timestamp = ? and capture_interval_name = ? and resource_type = ? and tag_names like ?",
        options[:timestamp],
        options[:interval_name],
        "VmOrTemplate",
        "%" + [options[:group_by_category], options[:group_by_tag]].join("/") + "%"
      ]
    end

    rows = model.where(cond).to_a
    return self.build(rows, options[:interval_name]), interval
  end

  def self.build(perfs, interval)
    perfs.inject([]) do |arr,perf|
      cols_hash = self.column_names.inject({:id => perf.resource_id}) do |h,c|
        col_options = self.columns_hash[c].options
        if interval == "daily"
          col = col_options[:daily_pfx] ? [col_options[:daily_pfx], c.to_s].join("_") : c
          value = perf.send(col)
          value = (value * col_options[:mult] * 24) if value && col_options[:mult]
        else
          value = perf.send(c)
          value = (value * col_options[:mult]) if value && col_options[:mult]
        end
        h[c] = value
        h
      end
      arr.push(self.new(cols_hash))
      arr
    end
  end

  def self.last_capture(interval_name = "hourly")
    first_and_last_capture(interval_name).last
  end

  def self.first_capture(interval_name = "hourly")
    first_and_last_capture(interval_name).first
  end

  def self.first_and_last_capture(interval_name = "hourly")
    klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)
    perf = klass
      .where(:capture_interval_name => interval_name, :resource_type => "VmOrTemplate")
      .select("MIN(timestamp) AS first_ts, MAX(timestamp) AS last_ts")
      .group(:resource_type)
      .first
    perf.nil? ? [] : [
      perf.first_ts.kind_of?(String) ? Time.zone.parse(perf.first_ts) : perf.first_ts,
      perf.last_ts.kind_of?(String)  ? Time.zone.parse(perf.last_ts)  : perf.last_ts
    ]
  end
end
