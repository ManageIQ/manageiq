class Chargeback < ActsAsArModel
  set_columns_hash(
    :start_date               => :datetime,
    :end_date                 => :datetime,
    :interval_name            => :string,
    :display_range            => :string,
    :vm_name                  => :string,
    :owner_name               => :string,
    :cpu_allocated_metric     => :float,
    :cpu_allocated_cost       => :float,
    :cpu_used_cost            => :float,
    :cpu_used_metric          => :float,
    :cpu_cost                 => :float,
    :cpu_metric               => :float,
    :disk_io_used_cost        => :float,
    :disk_io_used_metric      => :float,
    :disk_io_cost             => :float,
    :disk_io_metric           => :float,
    :fixed_compute_1_cost     => :float,
    :fixed_compute_2_cost     => :float,
    :fixed_storage_1_cost     => :float,
    :fixed_storage_2_cost     => :float,
    :fixed_2_cost             => :float,
    :fixed_cost               => :float,
    :memory_allocated_cost    => :float,
    :memory_allocated_metric  => :float,
    :memory_used_cost         => :float,
    :memory_used_metric       => :float,
    :memory_cost              => :float,
    :memory_metric            => :float,
    :net_io_used_cost         => :float,
    :net_io_used_metric       => :float,
    :net_io_cost              => :float,
    :net_io_metric            => :float,
    :storage_allocated_cost   => :float,
    :storage_allocated_metric => :float,
    :storage_used_cost        => :float,
    :storage_used_metric      => :float,
    :storage_cost             => :float,
    :storage_metric           => :float,
    :total_cost               => :float
  )

  RATES = YAML.load_file(File.join(Rails.root, "db/fixtures/chargeback_rates.yml"))

  def self.build_results_for_report_chargeback(options)
    # Options:
    #   :rpt_type => chargeback
    #   :interval => daily | weekly | monthly
    #   :start_time
    #   :end_time
    #   :end_interval_offset
    #   :interval_size
    #   :owner => <userid>
    #   :tag => /managed/environment/prod (Mutually exclusive with :user)
    #   :chargeback_type => detail | summary
    log_prefix = "MIQ(Chargeback.build_results_for_report_chargeback)"
    $log.info("#{log_prefix} Calculating chargeback costs...")

    tz = Metric::Helper.get_time_zone(options[:ext_options])
    tp = options[:ext_options][:time_profile] #TODO: Support time profiles
    interval = options[:interval] || "daily"
    cb = self.new
    report_user = User.where(:userid => options[:userid]).first

    # Find Vms by user or by tag
    if options[:owner]
      user = User.find_by_userid(options[:owner])
      if user.nil?
        $log.error("#{log_prefix} Unable to find user '#{options[:owner]}'. Calculating chargeback costs aborted.")
        raise MiqException::Error, "Unable to find user '#{options[:owner]}'"
      end
      vms = user.vms
    elsif options[:tag]
      vms = Vm.find_tagged_with(:all => options[:tag], :ns => "*")
      vms = vms & report_user.accessible_vms if report_user.self_service_user?
    else
      raise "must provide options :owner or :tag"
    end
    return [[]] if vms.empty?

    vm_owners = vms.inject({}) { |h,v| h[v.id] = v.evm_owner_name; h }
    options[:ext_options] ||= {}

    perf_cols = MetricRollup.column_names
    options[:ext_options][:only_cols] = Metric::BASE_COLS
    rates = ChargebackRate.find(:all, :conditions=>{:default=>true})
    rates.each do |rate|
      options[:ext_options][:only_cols] += rate.chargeback_rate_details.collect do |r|
        r.metric if perf_cols.include?(r.metric.to_s)
      end.compact
    end

    start_time, end_time = self.get_report_time_range(options, interval, tz)
    data = {}

    (start_time..end_time).step_value(1.day).each_cons(2) do |query_start_time, query_end_time|
      if options[:tag] && !report_user.self_service_user?
        cond = ["resource_type = ? and resource_id IS NOT NULL and timestamp >= ? and timestamp < ? and capture_interval_name = ? and tag_names like ? ",
                "VmOrTemplate",
                query_start_time,
                query_end_time,
                "hourly",
                "%" + options[:tag].split("/")[2..-1].join("/") + "%"
               ]
      else
        cond = ["resource_type = ? and resource_id IN (?) and timestamp >= ? and timestamp < ? and capture_interval_name = ?",
                "VmOrTemplate",
                vm_owners.keys,
                query_start_time,
                query_end_time,
                "hourly"
               ]
      end
      $log.debug("#{log_prefix} Conditions: #{cond.inspect}")

      recs = MetricRollup.all(
        :conditions => cond,
        :include => {:resource => :hardware, :parent_host => :tags, :parent_ems_cluster => :tags, :parent_storage => :tags, :parent_ems => :tags},
        :select => options[:ext_options][:only_cols].join(","),
        :order => "resource_id, timestamp"
      )
      recs = Metric::Helper.remove_duplicate_timestamps(recs)
      $log.info("#{log_prefix} Found #{recs.length} records for time range #{[query_start_time, query_end_time].inspect}")

      unless recs.empty?
        ts     = recs.first.timestamp.in_time_zone(tz).midnight
        ts_key = self.get_group_key_ts(recs.first, interval, tz)

        recs.each do |perf|
          next if perf.resource.nil?
          key = "#{perf.resource_id}_#{ts_key}"
          vm_owners[perf.resource_id] ||= perf.resource.evm_owner_name

          if data[key].nil?
            start_ts, end_ts, display_range = self.get_time_range(perf, interval, tz)
            data[key] = {
              "start_date"    => start_ts,
              "end_date"      => end_ts,
              "display_range" => display_range,
              "interval_name" => interval,
              "vm_name"       => perf.resource_name,
              "owner_name"    => vm_owners[perf.resource_id]
            }
          end

          rates_to_apply = cb.get_rates(perf)
          self.calculate_costs(perf, data[key], rates_to_apply)
        end
      end
    end
    $log.info("#{log_prefix} Calculating chargeback costs...Complete")

    return [data.inject([]) {|a,r| a << self.new(r.last)}]
  end

  def get_rates(perf)
    @rates      ||= {}
    @enterprise ||= MiqEnterprise.my_enterprise

    tags = perf.tag_names.split("|").reject {|n| n.starts_with?("folder_path_")}.sort.join("|")
    key = "#{tags}_#{perf.parent_host_id}_#{perf.parent_ems_cluster_id}_#{perf.parent_storage_id}_#{perf.parent_ems_id}"
    return @rates[key] if @rates.has_key?(key)

    tag_list = perf.tag_names.split("|").inject([]) {|arr,t| arr << "vm/tag/managed/#{t}"; arr}

    parents = [perf.parent_host, perf.parent_ems_cluster, perf.parent_storage, perf.parent_ems, @enterprise].compact

    @rates[key] = ChargebackRate.get_assigned_for_target(perf.resource, :tag_list => tag_list, :parents => parents, :associations_preloaded => true)
  end

  def self.column_names
    @column_names ||= self.columns.collect { |c| c.name }.sort
  end

  def self.calculate_costs(perf, h, rates)
    # This expects perf interval to be hourly. That will be the most granular interval available for chargeback.
    raise "expected 'hourly' performance interval but got '#{perf.capture_interval_name}" unless perf.capture_interval_name == "hourly"

    rates.each do |rate|
      rate.chargeback_rate_details.each do |r|
        cost_key         = "#{r.rate_name}_cost"
        metric_key       = "#{r.rate_name}_metric"
        cost_group_key   = "#{r.group}_cost"
        metric_group_key = "#{r.group}_metric"

        rec    = r.metric && perf.respond_to?(r.metric) ? perf : perf.resource
        metric = r.metric.nil? ? 0 : rec.send(r.metric) || 0
        cost   = r.cost(metric)

        col_hash = Hash.new
        [metric_key, metric_group_key].each             { |col| col_hash[col] = metric }
        [cost_key,   cost_group_key, 'total_cost'].each { |col| col_hash[col] = cost   }

        col_hash.each do |k, val|
          next unless self.column_names.include?(k)
          h[k] ||= 0
          h[k]  += val
        end
      end
    end
  end

  def self.get_group_key_ts(perf, interval, tz)
    ts = perf.timestamp.in_time_zone(tz)
    case interval
    when "daily"
      ts = ts.beginning_of_day
    when "weekly"
      ts = ts.beginning_of_week
    when "monthly"
      ts = ts.beginning_of_month
    else
      raise "interval '#{interval}' is not supported"
    end

    return ts
  end

  def self.get_time_range(perf, interval, tz)
    ts = perf.timestamp.in_time_zone(tz)
    case interval
    when "daily"
      [ts.beginning_of_day, ts.end_of_day, ts.strftime("%m/%d/%Y")]
    when "weekly"
      s_ts = ts.beginning_of_week
      e_ts = ts.end_of_week
      [s_ts, e_ts, "Week of #{s_ts.strftime("%m/%d/%Y")}"]
    when "monthly"
      s_ts = ts.beginning_of_month
      e_ts = ts.end_of_month
      [s_ts, e_ts, "#{s_ts.strftime("%b %Y")}"]
    else
      raise "interval '#{interval}' is not supported"
    end
  end

  def self.default_rates()
    rates = []
    ChargebackRate.find(:all, :conditions=>{:default=>true}).each do |rate|
      rates += rate.chargeback_rate_details
    end
    return rates
  end

  def self.get_report_time_range(options, interval, tz)
    return [options[:start_time], options[:end_time]] if options[:start_time]

    raise "Option 'interval_size' is required" if options[:interval_size].nil?

    options[:end_interval_offset] ||= 0
    options[:start_interval_offset] = (options[:end_interval_offset] + options[:interval_size] - 1)

    ts = Time.now.in_time_zone(tz)
    case interval
    when "daily"
      start_time = (ts - options[:start_interval_offset].days).beginning_of_day.utc
      end_time   = (ts - options[:end_interval_offset].days).end_of_day.utc
    when "weekly"
      start_time = (ts - options[:start_interval_offset].weeks).beginning_of_week.utc
      end_time   = (ts - options[:end_interval_offset].weeks).end_of_week.utc
    when "monthly"
      start_time = (ts - options[:start_interval_offset].months).beginning_of_month.utc
      end_time   = (ts - options[:end_interval_offset].months).end_of_month.utc
    else
      raise "interval '#{interval}' is not supported"
    end

    return [start_time, end_time]
  end

  def self.report_col_options
    {
      "cpu_allocated_cost"       => {:grouping => [:total]},
      "cpu_allocated_metric"     => {:grouping => [:total]},
      "cpu_cost"                 => {:grouping => [:total]},
      "cpu_metric"               => {:grouping => [:total]},
      "cpu_used_cost"            => {:grouping => [:total]},
      "cpu_used_metric"          => {:grouping => [:total]},
      "disk_io_cost"             => {:grouping => [:total]},
      "disk_io_metric"           => {:grouping => [:total]},
      "disk_io_used_cost"        => {:grouping => [:total]},
      "disk_io_used_metric"      => {:grouping => [:total]},
      "fixed_compute_1_cost"     => {:grouping => [:total]},
      "fixed_compute_2_cost"     => {:grouping => [:total]},
      "fixed_cost"               => {:grouping => [:total]},
      "fixed_storage_1_cost"     => {:grouping => [:total]},
      "fixed_storage_2_cost"     => {:grouping => [:total]},
      "memory_allocated_cost"    => {:grouping => [:total]},
      "memory_allocated_metric"  => {:grouping => [:total]},
      "memory_cost"              => {:grouping => [:total]},
      "memory_metric"            => {:grouping => [:total]},
      "memory_used_cost"         => {:grouping => [:total]},
      "memory_used_metric"       => {:grouping => [:total]},
      "net_io_cost"              => {:grouping => [:total]},
      "net_io_metric"            => {:grouping => [:total]},
      "net_io_used_cost"         => {:grouping => [:total]},
      "net_io_used_metric"       => {:grouping => [:total]},
      "storage_allocated_cost"   => {:grouping => [:total]},
      "storage_allocated_metric" => {:grouping => [:total]},
      "storage_cost"             => {:grouping => [:total]},
      "storage_metric"           => {:grouping => [:total]},
      "storage_used_cost"        => {:grouping => [:total]},
      "storage_used_metric"      => {:grouping => [:total]},
      "total_cost"               => {:grouping => [:total]}
    }
  end
end # class Chargeback
