module Metric::Purging
  def self.purge_date(type)
    value = VMDB::Config.new("vmdb").config.fetch_path(:performance, :history, type.to_sym)
    return if value.nil?

    value = value.to_i.days if value.kind_of?(Fixnum) # Default unit is days
    value = value.to_i_with_method.ago.utc unless value.nil?
    return value
  end

  def self.purge_all_timer
    self.purge_realtime_timer
    self.purge_rollup_timer
  end

  def self.purge_rollup_timer
    self.purge_hourly_timer
    self.purge_daily_timer
  end

  def self.purge_daily_timer(ts = nil)
    ts ||= self.purge_date(:keep_daily_performances) || 6.months.ago.utc
    self.purge_timer(ts, "daily")
  end

  def self.purge_hourly_timer(ts = nil)
    ts ||= self.purge_date(:keep_hourly_performances) || 6.months.ago.utc
    self.purge_timer(ts, "hourly")
  end

  def self.purge_realtime_timer(ts = nil)
    ts ||= self.purge_date(:keep_realtime_performances) || 4.hours.ago.utc
    self.purge_timer(ts, "realtime")
  end

  def self.purge_timer(ts, interval)
    MiqQueue.put_unless_exists(
      :class_name  => self.name,
      :method_name => "purge",
      :role        => "ems_metrics_processor",
      :queue_name  => "ems_metrics_processor",
      :state       => ["ready", "dequeue"],
      :args_selector => lambda { |args| args.kind_of?(Array) && args.last == interval }
    ) do |msg, find_options|
      find_options.merge(:args => [ts, interval])
    end
  end

  def self.purge_count(older_than, interval)
    klass, conditions = case interval
    when 'realtime'; [Metric,       {}]
    else             [MetricRollup, {:capture_interval_name => interval}]
    end

    oldest = klass.first(:select => :timestamp, :conditions => conditions, :order => :timestamp)
    oldest = oldest.nil? ? older_than : oldest.timestamp

    klass.count(:conditions => conditions.merge(:timestamp => oldest..older_than))
  end

  def self.purge(older_than, interval, window = nil, limit = nil)
    log_header = "MIQ(#{self.name}.purge)"
    $log.info("#{log_header} Purging #{limit.nil? ? "all" : limit} #{interval} metrics older than [#{older_than}]...")

    klass, conditions = case interval
    when 'realtime'; [Metric,       {}]
    else             [MetricRollup, {:capture_interval_name => interval}]
    end

    total = 0
    total_tag_values = 0
    _, timings = Benchmark.realtime_block(:total_time) do
      window ||= (VMDB::Config.new("vmdb").config.fetch_path(:performance, :history, :purge_window_size) || 1000)

      oldest = nil
      Benchmark.realtime_block(:query_oldest) do
        oldest = klass.first(:select => :timestamp, :conditions => conditions, :order => :timestamp)
        oldest = oldest.nil? ? older_than : oldest.timestamp
      end

      loop do
        batch, _ = Benchmark.realtime_block(:query_batch) do
          klass.all(:select => :id, :conditions => conditions.merge(:timestamp => oldest..older_than), :limit => window)
        end
        break if batch.empty?

        ids = batch.collect { |b| b.id }
        ids = ids[0, limit - total] if limit && total + ids.length > limit

        $log.info("#{log_header} Purging #{ids.length} #{interval} metrics.")
        Benchmark.realtime_block(:purge_metrics) do
          count  = klass.delete_all(:id => ids)
          total += count
        end

        if interval != 'realtime'
          # Since VimPerformanceTagValues are 6 * number of tags per performance
          # record, we need to batch in smaller trips.
          count_tag_values = 0
          $log.info("#{log_header} Purging associated tag values.")
          ids.each_slice(50) do |vp_ids|
            Benchmark.realtime_block(:purge_vim_performance_tag_values) do
              count = VimPerformanceTagValue.delete_all(:metric_id => vp_ids, :metric_type => klass.name)
              count_tag_values += count
              total_tag_values += count
            end
          end
          $log.info("#{log_header} Purged #{count_tag_values} associated tag values.")
        end

        yield(count, total) if block_given?

        break if limit && total >= limit
      end
    end

    $log.info("#{log_header} Purging #{limit.nil? ? "all" : limit} #{interval} metrics older than [#{older_than}]...Complete - Deleted #{total} records and #{total_tag_values} associated tag values - Timings: #{timings.inspect}")
  end
end
