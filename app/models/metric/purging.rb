module Metric::Purging
  def self.purge_date(type)
    value = ::Settings.performance.history[type]

    case value
    when Numeric
      value.days.ago.utc
    when String
      value.to_i_with_method.seconds.ago.utc
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
    ts ||= purge_date(:keep_daily_performances)
    purge_timer(ts, "daily")
  end

  def self.purge_hourly_timer(ts = nil)
    ts ||= purge_date(:keep_hourly_performances)
    purge_timer(ts, "hourly")
  end

  def self.purge_realtime_timer(ts = nil)
    ts ||= purge_date(:keep_realtime_performances)
    purge_timer(ts, "realtime")
  end

  def self.purge_timer(ts, interval)
    MiqQueue.put(
      :class_name  => name,
      :method_name => "purge_#{interval}",
      :args        => [ts],
      :msg_timeout => msg_timeout
    )
  end

  def self.purge_window_size
    ::Settings.performance.history.purge_window_size
  end

  def self.msg_timeout
    ::Settings.performance.history.queue_timeout.to_i_with_method
  end

  def self.purge_scope(older_than, interval)
    scope = interval == 'realtime' ? Metric : MetricRollup.where(:capture_interval_name => interval)
    scope.where(scope.arel_table[:timestamp].lteq(older_than))
  end

  def self.purge_count(older_than, interval)
    purge_scope(older_than, interval).count
  end

  # Used for MetricRollup (not Metric)
  # A list of ids (not a scope) is brought in and associated vimPerformanceTagValue records are deleted
  #
  # TODO: Would be more efficient to just use the full scope here (not id list)
  #   - we would then just use the standard purge_in_batches
  #   - remove the to_a from purge_in_batches
  #   - possibly use the standard purge_in_batches
  #   - change the metrics rollups to use truncate instead
  def self.purge_associated_records(metric_type, ids)
    # Since VimPerformanceTagValues are 6 * number of tags per performance
    # record, we need to batch in smaller trips.
    count_tag_values = 0
    _log.info("Purging associated tag values.")
    ids.each_slice(50) do |vp_ids|
      tv_count, = Benchmark.realtime_block(:purge_vim_performance_tag_values) do
        VimPerformanceTagValue.where(:metric_id => vp_ids, :metric_type => metric_type).delete_all
      end
      count_tag_values += tv_count
    end
    _log.info("Purged #{count_tag_values} associated tag values.")
    count_tag_values
  end

  def self.purge_daily(older_than, window = nil, total_limit = nil, &block)
    purge_by_date(older_than, "daily", window, total_limit, &block)
  end

  def self.purge_hourly(older_than, window = nil, total_limit = nil, &block)
    purge_by_date(older_than, "hourly", window, total_limit, &block)
  end

  def self.purge_realtime(older_than, window = nil, total_limit = nil, &block)
    truncate_child_tables(older_than)
  end

  # truncate metrics child tables
  # Determines hours not being preserved and truncates them
  # Used for realtime metrics.
  def self.truncate_child_tables(older_than)
    target_hours = determine_target_hours(older_than, Time.now.utc)
    return if target_hours.blank?

    target_hours.each do |hour|
      Metric.connection.truncate(Metric.reindex_table_name(hour), "Metric Truncate table #{hour}")
    end
  end

  def self.determine_target_hours(older_than, end_date)
    return [] if (end_date - older_than) > 24.hours

    start_hour = older_than.utc.hour
    end_hour = end_date.utc.hour
    end_hour += 24 if start_hour > end_hour

    good_hours = (start_hour..end_hour).map { |h| h % 24 }
    (0..23).to_a - good_hours.to_a
  end
  private_class_method :determine_target_hours

  def self.purge(older_than, interval, window = nil, total_limit = nil, &block)
    purge_by_date(older_than, interval, window, total_limit, &block)
  end

  def self.purge_by_date(older_than, interval, window = nil, total_limit = nil, &block)
    scope = purge_scope(older_than, interval)
    window ||= purge_window_size
    _log.info("Purging #{total_limit || "all"} #{interval} metrics older than [#{older_than}]...")
    total, total_tag_values, timings = purge_in_batches(scope, window, 0, total_limit, &block)
    _log.info("Purging #{total_limit || "all"} #{interval} metrics older than [#{older_than}]...Complete - " +
              "Deleted #{total} records and #{total_tag_values} associated tag values - Timings: #{timings.inspect}")

    total
  end

  def self.purge_in_batches(scope, window, total = 0, total_limit = nil)
    total_tag_values = 0
    query = scope.select(:id).limit(window)

    _, timings = Benchmark.realtime_block(:total_time) do
      loop do
        left_to_delete = total_limit && (total_limit - total)
        if total_limit && left_to_delete < window
          current_window = left_to_delete
          query = query.limit(current_window)
        end

        if scope.klass == MetricRollup
          batch_ids, _ = Benchmark.realtime_block(:query_batch) do
            query.pluck(:id)
          end
          break if batch_ids.empty?
          current_window = batch_ids.size
        else
          batch_ids = query
        end

        _log.info("Purging #{current_window} metrics.")
        count, = Benchmark.realtime_block(:purge_metrics) do
          scope.unscoped.where(:id => batch_ids).delete_all
        end
        break if count == 0
        total += count

        if scope.klass == MetricRollup
          count_tag_values = purge_associated_records(scope.name, batch_ids)
          total_tag_values += count_tag_values
        end

        yield(count, total) if block_given?
        break if count < window || (total_limit && (total_limit <= total))
      end
    end

    [total, total_tag_values, timings]
  end
end
