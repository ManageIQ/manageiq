class ManageIQ::Providers::Amazon::CloudManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  INTERVALS = [5.minutes, 1.minute]

  COUNTER_INFO = [
    {
      :amazon_counters       => ["CPUUtilization"],
      :calculation           => ->(stat, _) { stat },
      :vim_style_counter_key => "cpu_usage_rate_average"
    },

    {
      :amazon_counters       => ["DiskReadBytes", "DiskWriteBytes"],
      :calculation           => ->(*stats, interval) { stats.compact.sum / 1024.0 / interval },
      :vim_style_counter_key => "disk_usage_rate_average"
    },

    {
      :amazon_counters       => ["NetworkIn", "NetworkOut"],
      :calculation           => ->(*stats, interval) { stats.compact.sum / 1024.0 / interval },
      :vim_style_counter_key => "net_usage_rate_average"
    },
  ]

  COUNTER_NAMES = COUNTER_INFO.collect { |i| i[:amazon_counters] }.flatten.uniq

  VIM_STYLE_COUNTERS = {
    "cpu_usage_rate_average"  => {
      :counter_key           => "cpu_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "percent",
      :capture_interval_name => "realtime"
    },

    "disk_usage_rate_average" => {
      :counter_key           => "disk_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 2,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    },

    "net_usage_rate_average"  => {
      :counter_key           => "net_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 2,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    }
  }

  def perf_collect_metrics(interval_name, start_time = nil, end_time = nil)
    log_header = "[#{interval_name}] for: [#{target.class.name}], [#{target.id}], [#{target.name}]"

    end_time ||= Time.now
    end_time     = end_time.utc
    start_time ||= end_time - 4.hours # 4 hours for symmetry with VIM
    start_time   = start_time.utc

    begin
      perf_init_amazon
      perf_capture_data_amazon(start_time, end_time)
    rescue Exception => err
      _log.error("#{log_header} Unhandled exception during perf data collection: [#{err}], class: [#{err.class}]")
      _log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      _log.log_backtrace(err)
      raise
    ensure
      perf_release_amazon
    end
  end

  private

  #
  # Connect / Disconnect / Intialize methods
  #

  def perf_init_amazon
    raise "No EMS defined" if target.ext_management_system.nil?

    @perf_ems, = Benchmark.realtime_block(:connect) do
      # TODO: Fix connect timings.  Since Amazon is lazy connected, this is
      #       near instant, and is really reflected in the very first call
      target.ext_management_system.connect(:service => "CloudWatch")
    end
    @perf_ems
  end

  def perf_release_amazon
    @perf_ems = nil
  end

  #
  # Capture methods
  #

  def perf_capture_data_amazon(start_time, end_time)
    counters, = Benchmark.realtime_block(:capture_counters) do
      filter = [{:name => "InstanceId", :value => target.ems_ref}]
      @perf_ems.metrics.filter(:dimensions, filter).select { |m| m.name.in?(COUNTER_NAMES) }
    end

    # Since we are unable to determine if the first datapoint we get is a
    #   1-minute (detailed) or 5-minute (basic) interval, we will need to throw
    #   it away.  So, we ask for at least one datapoint earlier than what we
    #   need.
    start_time -= 5.minutes

    metrics_by_counter_name = {}
    counters.each do |c|
      metrics = metrics_by_counter_name[c.name] = {}

      # Only ask for 1 day at a time, since there is a limitation on the number
      #   of datapoints you are allowed to ask for from Amazon Cloudwatch.
      #   http://docs.amazonwebservices.com/AmazonCloudWatch/latest/APIReference/API_GetMetricStatistics.html
      (start_time..end_time).step_value(1.day).each_cons(2) do |st, et|
        statistics, = Benchmark.realtime_block(:capture_counter_values) do
          c.statistics(:start_time => st, :end_time => et, :statistics => ["Average"]).to_a
        end

        statistics.each { |s| metrics[s[:timestamp].utc] = s[:average] }
      end
    end

    counter_values_by_ts = {}
    COUNTER_INFO.each do |i|
      timestamps = i[:amazon_counters].collect do |c|
        metrics_by_counter_name[c].keys unless metrics_by_counter_name[c].nil?
      end.flatten.uniq.compact.sort

      # If we are unable to determine if a datapoint is a 1-minute (detailed)
      #   or 5-minute (basic) interval, we will throw it away.  This includes
      #   the very first interval.
      timestamps.each_cons(2) do |last_ts, ts|
        interval = ts - last_ts
        next unless interval.in?(INTERVALS)

        metrics = i[:amazon_counters].collect { |c| metrics_by_counter_name.fetch_path(c, ts) }
        value   = i[:calculation].call(*metrics, interval)

        # For (temporary) symmetry with VIM API we create 20-second intervals.
        (last_ts + 20.seconds..ts).step_value(20.seconds).each do |inner_ts|
          counter_values_by_ts.store_path(inner_ts.iso8601, i[:vim_style_counter_key], value)
        end
      end
    end

    counters_by_id              = {target.ems_ref => VIM_STYLE_COUNTERS}
    counter_values_by_id_and_ts = {target.ems_ref => counter_values_by_ts}
    return counters_by_id, counter_values_by_id_and_ts
  end
end
