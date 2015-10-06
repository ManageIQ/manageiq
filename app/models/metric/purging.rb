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

  def self.purge_count(older_than, interval)
    klass, conditions = case interval
                        when 'realtime' then [Metric,       {}]
                        else             [MetricRollup, {:capture_interval_name => interval}]
                        end

    oldest = klass.select(:timestamp).where(conditions).order(:timestamp).first
    oldest = oldest.nil? ? older_than : oldest.timestamp

    klass.where(conditions).where(:timestamp => oldest..older_than).count
  end

  def self.purge(older_than, interval, window = nil, limit = nil)
    _log.info("Purging #{limit.nil? ? "all" : limit} #{interval} metrics older than [#{older_than}]...")

    klass, conditions = case interval
                        when 'realtime' then [Metric,       {}]
                        else             [MetricRollup, {:capture_interval_name => interval}]
                        end

    total = 0
    total_tag_values = 0
    _, timings = Benchmark.realtime_block(:total_time) do
      window ||= (VMDB::Config.new("vmdb").config.fetch_path(:performance, :history, :purge_window_size) || 1000)

      oldest = nil
      Benchmark.realtime_block(:query_oldest) do
        oldest = klass.select(:timestamp).where(conditions).order(:timestamp).first
        oldest = oldest.nil? ? older_than : oldest.timestamp
      end

      loop do
        batch, = Benchmark.realtime_block(:query_batch) do
          klass.select(:id).where(conditions).where(:timestamp => (oldest..older_than)).limit(window)
        end
        break if batch.empty?

        ids = batch.collect(&:id)
        ids = ids[0, limit - total] if limit && total + ids.length > limit

        _log.info("Purging #{ids.length} #{interval} metrics.")
        count, = Benchmark.realtime_block(:purge_metrics) do
          klass.delete_all(:id => ids)
        end
        total += count

        if interval != 'realtime'
          # Since VimPerformanceTagValues are 6 * number of tags per performance
          # record, we need to batch in smaller trips.
          count_tag_values = 0
          _log.info("Purging associated tag values.")
          ids.each_slice(50) do |vp_ids|
            tv_count, = Benchmark.realtime_block(:purge_vim_performance_tag_values) do
              VimPerformanceTagValue.delete_all(:metric_id => vp_ids, :metric_type => klass.name)
            end
            count_tag_values += tv_count
            total_tag_values += tv_count
          end
          _log.info("Purged #{count_tag_values} associated tag values.")
        end

        yield(count, total) if block_given?

        break if limit && total >= limit
      end
    end

    _log.info("Purging #{limit.nil? ? "all" : limit} #{interval} metrics older than [#{older_than}]...Complete - Deleted #{total} records and #{total_tag_values} associated tag values - Timings: #{timings.inspect}")
  end
end
