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
      $log.error("#{log_header} Unhandled exception during perf data collection: [#{err}], class: [#{err.class}]")
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

  def list_meters(field_name = "resource_id", capture_method = :capture_counters)
    instance_filter = {"field" => field_name, "value" => self.ems_ref}
    counters, _ = Benchmark.realtime_block(capture_method) do
      @perf_ems.list_meters([instance_filter]).body
    end
    counters.each { |c| c[:instance_filter] = instance_filter }
    counters
  end

  def list_metadata_meters
    list_meters("metadata.instance_id", :capture_meta_counters)
  end

  def meter_names
    @meter_names ||= Metric::Capture::Openstack::COUNTER_NAMES
  end

  def find_meter_counters
    counters = list_meters + list_metadata_meters
    counters.select { |c| meter_names.include? c["name"] }
  end

  def perf_capture_data_openstack(start_time, end_time)
    # some meters can get gathered by directly querying for the "resource_id",
    #   but other meters can only be gathered by examining the
    #   "metadata.instance_id"
    log_header = "MIQ(#{self.class.name}.perf_collect_data_openstack) [#{start_time} - #{end_time}]"

    counters = find_meter_counters

    # We will have to account for the fact that each counter can be configured
    # for individual capture intervals ... the out-of-box default is 10min
    start_time -= 10.minutes

    metrics_by_counter_name = {}
    counters.each do |c|
      metrics_by_counter_name[c["name"]] = collect_metrics_by_counter(c, start_time, end_time)
    end

    ## process the openstack statistics to make them look like vmware statistics
    counter_values_by_ts = process_statistics(metrics_by_counter_name)

    counters_by_id              = {self.ems_ref => Metric::Capture::Openstack::VIM_STYLE_COUNTERS}
    counter_values_by_id_and_ts = {self.ems_ref => counter_values_by_ts}
    return counters_by_id, counter_values_by_id_and_ts
  end

  def collect_metrics_by_counter(counter, start_time, end_time)
    metrics = {}

    # For now, this logic just mirrors how we capture Amazon CloudWatch data
    # (see amazon.rb)
    (start_time..end_time).step_value(1.day).each_cons(2) do |st, et|
      filter = [{"field" => "timestamp", "op" => "lt", "value" => et.iso8601},
                {"field" => "timestamp", "op" => "gt", "value" => st.iso8601},
                counter[:instance_filter]]
      statistics, _ = Benchmark.realtime_block(:capture_counter_values) do
        # try to capture for every 20s over the timeframe ... however, the
        # server can be configured for any arbitrary capture interval
        # we'll deal with that below
        @perf_ems.get_statistics(counter["name"], 'period' => 20, 'q' => filter).body
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
    metrics
  end

  def process_statistics(metrics_by_counter_name)
    log_header = "MIQ(#{self.class.name}.#{__method__})"
    counter_values_by_ts = {}

    # Sometimes the metric capture intervals slightly exceed the configured
    # value when openstack is under heavy load.
    # Capture the extra seconds in the remainder values
    remainder_seconds    = 0
    remainder_value      = 0

    Metric::Capture::Openstack::COUNTER_INFO.each do |i|
      timestamps = i[:openstack_counters].collect { |c| metrics_by_counter_name[c].try(:keys) }.flatten.compact.uniq.sort

      # loop through each interval and break it down into 20sec chunks
      # this is purely to match vmware C&U logic
      timestamps.each_cons(2) do |ts, next_ts|
        interval = next_ts - ts
        # skip any intervals that are fewer than 20sec
        if interval < 20.seconds
          $log.warn("#{log_header} [#{self.name}] Capture interval invalid--fewer than 20sec.  #{ts} - #{next_ts}")
          next
        end
        metrics  = i[:openstack_counters].collect { |c| metrics_by_counter_name.fetch_path(c, ts) }
        value    = i[:calculation].call(*metrics, interval)

        # Some meters store the cumulative values instead of snapshots of usage
        # (e.g., disk reads).
        # break down cumulative meter values into discrete values
        # e.g., 10, 20, 25, 35, 40 => 10, 10, 5, 10, 5
        if Metric::Capture::Openstack.is_diff_meter? i[:openstack_counters]
          next_metrics = i[:openstack_counters].collect { |c| metrics_by_counter_name.fetch_path(c, next_ts) }
          next_value   = i[:calculation].call(*next_metrics, interval)
          value        = next_value - value
        end

        # add in the remainder and previous value from the previous interval
        # and create a single 20 second time slot with a value that's the
        # average of the previous interval's value and this interval's value
        if remainder_seconds > 0
          # steal from the current interval in order to create a "catchup" value
          interval -= (20 - remainder_seconds)
          ts       += (20 - remainder_seconds)

          # store the catchup value in the hash
          catchup_value = (value + remainder_value) / 2
          counter_values_by_ts.store_path((ts - 20.seconds).iso8601, i[:vim_style_counter_key], catchup_value)
        end

        # determine if there's a remainder for the next iteration
        remainder_seconds = interval % 20
        remainder_value   = value

        # divide the interval into 20s segments ... each segment gets the value
        # for the entire interval
        range = (remainder_seconds == 0) ? (ts..next_ts) : (ts...(next_ts - 20.seconds))
        range.step_value(20.seconds).each do |timestamp|
          counter_values_by_ts.store_path(timestamp.iso8601, i[:vim_style_counter_key], value)
        end
      end
    end
    counter_values_by_ts
  end
end
