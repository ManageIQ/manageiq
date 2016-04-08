class ChargebackVm < Chargeback
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

  def self.build_results_for_report_ChargebackVm(options)
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
    _log.info("Calculating chargeback costs...")

    tz = Metric::Helper.get_time_zone(options[:ext_options])
    # TODO: Support time profiles via options[:ext_options][:time_profile]

    interval = options[:interval] || "daily"
    cb = new
    report_user = User.find_by(:userid => options[:userid])

    # Find Vms by user or by tag
    if options[:owner]
      user = User.find_by_userid(options[:owner])
      if user.nil?
        _log.error("Unable to find user '#{options[:owner]}'. Calculating chargeback costs aborted.")
        raise MiqException::Error, _("Unable to find user '%{name}'") % {:name => options[:owner]}
      end
      vms = user.vms
    elsif options[:tag]
      vms = Vm.find_tagged_with(:all => options[:tag], :ns => "*")
      vms &= report_user.accessible_vms if report_user && report_user.self_service?
    elsif options[:tenant_id]
      tenant = Tenant.find(options[:tenant_id])
      if tenant.nil?
        _log.error("Unable to find tenant '#{options[:tenant_id]}'. Calculating chargeback costs aborted.")
        raise MiqException::Error, "Unable to find tenant '#{options[:tenant_id]}'"
      end
      vms = tenant.vms
    else
      raise _("must provide options :owner or :tag")
    end
    return [[]] if vms.empty?

    vm_owners = vms.inject({}) { |h, v| h[v.id] = v.evm_owner_name; h }
    options[:ext_options] ||= {}

    base_rollup = MetricRollup.includes(
      :resource           => :hardware,
      :parent_host        => :tags,
      :parent_ems_cluster => :tags,
      :parent_storage     => :tags,
      :parent_ems         => :tags)
                              .select(*Metric::BASE_COLS).order("resource_id, timestamp")
    perf_cols = MetricRollup.attribute_names
    rate_cols = ChargebackRate.where(:default => true).flat_map do |rate|
      rate.chargeback_rate_details.map(&:metric).select { |metric| perf_cols.include?(metric.to_s) }
    end
    base_rollup = base_rollup.select(*rate_cols)

    timerange = get_report_time_range(options, interval, tz)
    data = {}

    timerange.step_value(1.day).each_cons(2) do |query_start_time, query_end_time|
      recs = base_rollup.where(:timestamp => query_start_time...query_end_time, :capture_interval_name => "hourly")
      if options[:tag] && (report_user.nil? || !report_user.self_service?)
        recs = recs.where(:resource_type => "VmOrTemplate")
                   .where.not(:resource_id => nil)
                   .for_tag_names(options[:tag].split("/")[2..-1])
      else
        recs = recs.where(:resource_type => "VmOrTemplate", :resource_id => vm_owners.keys)
      end

      recs = Metric::Helper.remove_duplicate_timestamps(recs)
      _log.info("Found #{recs.length} records for time range #{[query_start_time, query_end_time].inspect}")

      unless recs.empty?
        ts_key = get_group_key_ts(recs.first, interval, tz)

        recs.each do |perf|
          next if perf.resource.nil?
          key = "#{perf.resource_id}_#{ts_key}"
          vm_owners[perf.resource_id] ||= perf.resource.evm_owner_name

          if data[key].nil?
            start_ts, end_ts, display_range = get_time_range(perf, interval, tz)
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
          calculate_costs(perf, data[key], rates_to_apply)
        end
      end
    end
    _log.info("Calculating chargeback costs...Complete")

    [data.map { |r| new(r.last) }]
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
