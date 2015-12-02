module Metric::Purging
  def self.purge_date(type)
    value = VMDB::Config.new("vmdb").config.fetch_path(:performance, :history, type.to_sym)
    return if value.nil?

    case value
    when Numeric
      value.days.ago.utc
    when String
      value.to_i_with_method.seconds.ago.utc
    when nil
    end
  end

  def self.purge_all_timer
    purge_realtime_timer
    purge_rollup_timer
  end

  def self.purge_rollup_timer
    purge_hourly_timer
    purge_daily_timer
  end

  def self.purge_daily_timer(ts = nil)
    ts ||= purge_date(:keep_daily_performances) || 6.months.ago.utc
    purge_timer(ts, "daily")
  end

  def self.purge_hourly_timer(ts = nil)
    ts ||= purge_date(:keep_hourly_performances) || 6.months.ago.utc
    purge_timer(ts, "hourly")
  end

  def self.purge_realtime_timer(ts = nil)
    ts ||= purge_date(:keep_realtime_performances) || 4.hours.ago.utc
    purge_timer(ts, "realtime")
  end

  def self.purge_timer(ts, interval)
    MiqQueue.put_unless_exists(
      :class_name    => name,
      :method_name   => "purge",
      :role          => "ems_metrics_processor",
      :queue_name    => "ems_metrics_processor",
      :state         => ["ready", "dequeue"],
      :args_selector => ->(args) { args.kind_of?(Array) && args.last == interval }
    ) do |_msg, find_options|
      find_options.merge(:args => [ts, interval])
    end
  end

  def self.scope_for_interval(interval)
    interval == 'realtime' ? Metric : MetricRollup.where(:capture_interval_name => interval)
  end

  def self.purge_count(older_than, interval)
    scope_for_interval(interval).where('timestamp <= ?', older_than).count
  end

  def self.purge(older_than, interval, window = nil, limit = nil)
    _log.info("Purging #{limit.nil? ? "all" : limit} #{interval} metrics older than [#{older_than}]...")

    scope = scope_for_interval(interval)

    total = 0
    total_tag_values = 0
    _, timings = Benchmark.realtime_block(:total_time) do
      window ||= (VMDB::Config.new("vmdb").config.fetch_path(:performance, :history, :purge_window_size) || 1000)

      while limit.nil? || total < limit
        current_limit = limit.nil? ? window : [window, limit - total].min
        ids, = Benchmark.realtime_block(:query_batch) do
          scope.where('timestamp <= ?', older_than).limit(current_limit).pluck(:id)
        end
        break if ids.empty?

        _log.info("Purging #{ids.length} #{interval} metrics.")
        count, = Benchmark.realtime_block(:purge_metrics) do
          scope.unscoped.delete_all(:id => ids)
        end
        total += count

        if interval != 'realtime'
          # Since VimPerformanceTagValues are 6 * number of tags per performance
          # record, we need to batch in smaller trips.
          count_tag_values = 0
          _log.info("Purging associated tag values.")
          ids.each_slice(50) do |vp_ids|
            tv_count, = Benchmark.realtime_block(:purge_vim_performance_tag_values) do
              VimPerformanceTagValue.delete_all(:metric_id => vp_ids, :metric_type => scope.name)
            end
            count_tag_values += tv_count
            total_tag_values += tv_count
          end
          _log.info("Purged #{count_tag_values} associated tag values.")
        end

        yield(count, total) if block_given?
      end
    end

    _log.info("Purging #{limit.nil? ? "all" : limit} #{interval} metrics older than [#{older_than}]...Complete - Deleted #{total} records and #{total_tag_values} associated tag values - Timings: #{timings.inspect}")
  end
end
