module Metric::CiMixin::Capture::Openstack
  def perf_collect_metrics_openstack(interval_name, start_time = nil, end_time = nil)
    target = "[#{self.class.name}], [#{self.id}], [#{self.name}]"
    log_header = "MIQ(#{self.class.name}.perf_collect_metrics_openstack) [#{interval_name}] for: #{target}"

    end_time   ||= Time.now
    end_time     = end_time.utc
    start_time ||= end_time - 4.hours # 4 hours for symmetry with VIM
    start_time   = start_time.utc

    $log.debug "#{log_header} start_time: #{start_time}, end_time: #{end_time}"

    begin
      @perf_ems = perf_init_openstack
      perf_capture_data_openstack(start_time, end_time)
    rescue Exception => err
      $log.error("#{log_header} Unhandled exception during perf data collection: [#{err.to_s}], class: [#{err.class.to_s}]")
      $log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      $log.log_backtrace(err)
      raise
    ensure
      perf_release_openstack
    end
  end

  def perf_init_openstack
    raise "No EMS defined" if self.ext_management_system.nil?

    metering_service, _ = Benchmark.realtime_block(:connect) do
      self.ext_management_system.connect(:service => "Metering")
    end
    metering_service
  end

  def perf_release_openstack
    @perf_ems = nil
  end

  def perf_capture_data_openstack(start_time, end_time)
    # some meters can get gathered by directly querying for the "resource_id",
    #   but other meters can only be gathered by examining the
    #   "metadata.instance_id"
    log_header = "MIQ(#{self.class.name}.perf_collect_data_openstack) [#{start_time} - #{end_time}]"
    counter_instance_filters = {}
    instance_filter = {"field" => "resource_id", "value" => self.ems_ref}
    counters, _ = Benchmark.realtime_block(:capture_counters) do
      @perf_ems.list_meters([instance_filter]).body
    end
    counters.each {|m| m[:instance_filter] = instance_filter}

    instance_filter = {"field" => "metadata.instance_id", "value" => self.ems_ref}
    meta_counters, _ = Benchmark.realtime_block(:capture_meta_counters) do
      @perf_ems.list_meters([instance_filter]).body
    end
    meta_counters.each {|m| m[:instance_filter] = instance_filter}
    counters += meta_counters

    counters.select! {|c| Metric::Capture::Openstack::COUNTER_NAMES.include? c["name"]}

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
          @perf_ems.get_statistics(c["name"], options={'period'=>20, 'q'=>filter}).body
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
    Metric::Capture::Openstack::COUNTER_INFO.each do |i|
      timestamps = i[:openstack_counters].collect { |c| metrics_by_counter_name[c].try(:keys) }.flatten.compact.uniq.sort

      aggregate = []
      agg_start = nil
      timestamps.each_cons(2) do |last_ts, ts|
        agg_start ||= last_ts

        interval     = ts - last_ts
        metrics      = i[:openstack_counters].collect { |c| metrics_by_counter_name.fetch_path(c, ts) }
        value        = i[:calculation].call(*metrics, interval)

        # break down values from cumulative meters into discrete values
        if Metric::Capture::Openstack.is_diff_meter? i[:openstack_counters]
          last_metrics = i[:openstack_counters].collect { |c| metrics_by_counter_name.fetch_path(c, last_ts) }
          last_value   = i[:calculation].call(*last_metrics, interval)
          value = value - last_value
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
            value = aggregate.inject(0.0){|sum, el| sum + el} / aggregate.size
            last_ts = agg_start
            agg_start = ts
          else
            # the aggregate is still not divisible by 20, grab the next stat
            next
          end
        end

        # For (temporary) symmetry with VIM API we create 20-second intervals.
        (last_ts + 20.seconds..ts).step_value(20.seconds).each do |ts|
          counter_values_by_ts.store_path(ts.iso8601, i[:vim_style_counter_key], value)
        end
      end
    end

    counters_by_id              = {self.ems_ref => Metric::Capture::Openstack::VIM_STYLE_COUNTERS}
    counter_values_by_id_and_ts = {self.ems_ref => counter_values_by_ts}
    return counters_by_id, counter_values_by_id_and_ts
  end
end
