module Metric::CiMixin::Capture::OpenstackBase
  def perf_collect_metrics_openstack(capture_data_method, interval_name, start_time = nil, end_time = nil)
    target = "[#{self.class.name}], [#{id}], [#{name}]"
    log_header = "MIQ(#{self.class.name}.perf_collect_metrics_openstack) [#{interval_name}] for: #{target}"

    end_time   ||= Time.now
    end_time     = end_time.utc
    start_time ||= end_time - 4.hours # 4 hours for symmetry with VIM
    start_time   = start_time.utc

    $log.debug "#{log_header} start_time: #{start_time}, end_time: #{end_time}"

    begin
      @perf_ems = perf_init_openstack
      send(capture_data_method, start_time, end_time)
    rescue Exception => err
      $log.error("#{log_header} Unhandled exception during perf data collection: [#{err}], class: [#{err.class}]")
      $log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      $log.log_backtrace(err)
      raise
    ensure
      perf_release_openstack
    end
  end

  def perf_init_openstack
    raise "No EMS defined" if ext_management_system.nil?

    metering_service, _ = Benchmark.realtime_block(:connect) do
      ext_management_system.connect(:service => "Metering")
    end
    metering_service
  end

  def perf_release_openstack
    @perf_ems = nil
  end

  def perf_capture_data_openstack_base(metric_capture_module, start_time, end_time, resource_filter, metadata_filter)
    # some meters can get gathered by directly querying for the "resource_id",
    #   but other meters can only be gathered by examining the
    #   "metadata.instance_id"
    log_header = "MIQ(#{self.class.name}.perf_collect_data_openstack) [#{start_time} - #{end_time}]"
    $log.debug "#{log_header} start_time: #{start_time}, end_time: #{end_time}"

    instance_filter = resource_filter
    if resource_filter
      $log.debug "#{log_header} getting resource counters using resource filter: #{resource_filter}"
      counters, _ = Benchmark.realtime_block(:capture_counters) do
        @perf_ems.list_meters([instance_filter]).body
      end
      counters.each { |m| m[:instance_filter] = instance_filter }
    else
      $log.debug "#{log_header} no resource filter provided"
      counters = []
    end

    instance_filter = metadata_filter
    if metadata_filter
      $log.debug "#{log_header} getting metadata counters using metadata filter: #{metadata_filter}"
      meta_counters, _ = Benchmark.realtime_block(:capture_meta_counters) do
        @perf_ems.list_meters([instance_filter]).body
      end
    else
      $log.debug "#{log_header} no metadata filter provided"
      meta_counters = []
    end

    meta_counters.each { |m| m[:instance_filter] = instance_filter }
    counters += meta_counters

    counters.select! { |c| metric_capture_module::COUNTER_NAMES.include? c["name"] }

    # We will have to account for the fact that each counter can be configured
    # for individual capture intervals ... the out-of-box default is 10min
    start_time -= 10.minutes

    metrics_by_counter_name = {}
    counters.each do |c|
      metrics = metrics_by_counter_name[c["name"]] = {}

      # For now, this logic just mirrors how we capture Amazon CloudWatch data
      # (see amazon.rb)
      (start_time..end_time).step_value(1.day).each_cons(2) do |st, et|
        filter = [{"field" => "timestamp", "op" => "lt", "value" => et.iso8601},
                  {"field" => "timestamp", "op" => "gt", "value" => st.iso8601},
                  c[:instance_filter]]
        statistics, _ = Benchmark.realtime_block(:capture_counter_values) do
          # try to capture for every 20s over the timeframe ... however, the
          # server can be configured for any arbitrary capture interval
          # we'll deal with that below
          options = {'period' => 20, 'q' => filter}
          @perf_ems.get_statistics(c["name"], options).body
        end

        # This is a pretty bad hack to work around a problem with the timestamp
        #   values that come back from ceilometer.  The timestamps come back
        #   without a timezone specifier, e.g.: "2013-08-23T20:06:09".
        #   The time value is actually in UTC, but there's nothing about the
        #   string which indicates that.
        # This hack looks at the length of the string and tries to determine if
        #   the timezone information is missing.  If so, it appends "Z" (zulu
        #   time) to the string to indicate UTC before it is parsed.  This will
        #   force a UTC timezone in order to keep the value consistent with what
        #   was intended--but not indicated--by ceilometer.
        # http://lists.openstack.org/pipermail/openstack-dev/2012-November/002235.html
        statistics.each do |s|
          duration_end = s["duration_end"]
          duration_end << "Z" if duration_end.size == 19
          timestamp = Time.parse(duration_end)
          metrics[timestamp] = s["avg"]
        end
      end
    end

    counter_values_by_ts = {}
    metric_capture_module::COUNTER_INFO.each do |i|
      timestamps = i[:openstack_counters].collect { |c| metrics_by_counter_name[c].try(:keys) }
      timestamps = timestamps.flatten.compact.uniq.sort

      aggregate = []
      agg_start = nil
      timestamps.each_cons(2) do |last_ts, ts|
        agg_start ||= last_ts

        interval     = ts - last_ts
        metrics      = i[:openstack_counters].collect { |c| metrics_by_counter_name.fetch_path(c, ts) }
        value        = i[:calculation].call(*metrics, interval)

        # break down values from cumulative meters into discrete values
        if metric_capture_module.diff_meter? i[:openstack_counters]
          last_metrics = i[:openstack_counters].collect { |c| metrics_by_counter_name.fetch_path(c, last_ts) }
          last_value   = i[:calculation].call(*last_metrics, interval)
          value -= last_value
        end

        # if the interval is not divisible by 20, keep an aggregate interval
        # the two main risks here are:
        #   1. the openstack admin configured a crazy interval like 17sec
        #   2. one of the configured intervals contains an outlier that is
        #      "sanded down" by the surrounding aggregated values
        if interval % 20 != 0
          aggregate << value
          interval = ts - agg_start
          # if the aggregate interval is divisible by 20,
          #   average over the aggregate
          #   reset the last_ts for the VIM API symmetry below
          #   reset the agg_start
          if interval % 20 == 0
            value = aggregate.inject(0.0) { |sum, el| sum + el } / aggregate.size
            last_ts = agg_start
            agg_start = ts
          else
            # the aggregate is still not divisible by 20, grab the next stat
            next
          end
        end

        # For (temporary) symmetry with VIM API we create 20-second intervals.
        (last_ts + 20.seconds..ts).step_value(20.seconds).each do |ts_item|
          counter_values_by_ts.store_path(ts_item.iso8601, i[:vim_style_counter_key], value)
        end
      end
    end

    counters_by_id              = {ems_ref => metric_capture_module::VIM_STYLE_COUNTERS}
    counter_values_by_id_and_ts = {ems_ref => counter_values_by_ts}
    return counters_by_id, counter_values_by_id_and_ts
  end
end
