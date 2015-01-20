module VmdbMetric::Purging
  extend ActiveSupport::Concern

  module ClassMethods
    def purge_date(interval)
      type  = "keep_#{interval}_metrics".to_sym
      value = VMDB::Config.new("vmdb").config.fetch_path(:database, :metrics_history, type)
      value = value.to_i.days if value.kind_of?(Fixnum) # Default unit is days
      value = value.to_i_with_method.seconds.ago.utc unless value.nil?
      value
    end

    def purge_all_timer
      self.purge_hourly_timer
      self.purge_daily_timer
    end

    def purge_daily_timer(ts = nil)
      interval = "daily"
      mode = :date  # Only support :date mode, not :remaining mode
      ts ||= self.purge_date(interval) || 6.months.ago.utc
      self.purge_timer(mode, ts, interval)
    end

    def purge_hourly_timer(ts = nil)
      interval = "hourly"
      mode = :date  # Only support :date mode, not :remaining mode
      ts ||= self.purge_date(interval) || 6.months.ago.utc
      self.purge_timer(mode, ts, interval)
    end

    def purge_timer(mode, value, interval)
      MiqQueue.put_unless_exists(
        :class_name    => self.name,
        :method_name   => "purge",
        :role          => "database_operations",
        :queue_name    => "generic",
        :state         => ["ready", "dequeue"],
        :args_selector => lambda { |args| args.kind_of?(Array) && args.last == interval }
      ) do |msg, find_options|
        find_options.merge(:args => [mode, value, interval])
      end
    end

    def purge_window_size
      VMDB::Config.new("vmdb").config.fetch_path(:database, :metrics_history, :purge_window_size) || 10000
    end

    def purge_count(mode, value, interval)
      self.send("purge_count_by_#{mode}", value, interval)
    end

    def purge(mode, value, interval, window = nil, &block)
      self.send("purge_by_#{mode}", value, interval, window, &block)
    end

    private

    #
    # By Date
    #

    def purge_count_by_date(older_than, interval)
      self.where(:capture_interval_name => interval).where(self.arel_table[:timestamp].lt(older_than)).count
    end

    def purge_by_date(older_than, interval, window = nil, &block)
      log_header = "MIQ(#{self.name}.purge)"
      $log.info("#{log_header} Purging #{interval} metrics older than [#{older_than}]...")

      window ||= purge_window_size
      t = self.arel_table
      conditions = [{:capture_interval_name => interval}, self.arel_table[:timestamp].lt(older_than)]
      total = purge_in_batches(conditions, window, &block)

      $log.info("#{log_header} Purging #{interval} metrics older than [#{older_than}]...Complete - Deleted #{total} records")
    end

    #
    # Common methods
    #

    def purge_in_batches(conditions, window, total = 0)
      query = self.select(:id).limit(window)
      [conditions].flatten.each { |c| query = query.where(c) }

      until (batch = query.dup.to_a).empty?
        ids = batch.collect(&:id)

        $log.info("MIQ(#{self.name}.purge) Purging #{ids.length} metrics.")
        count  = self.delete_all(:id => ids)
        total += count

        purge_associated_records(ids) if self.respond_to?(:purge_associated_records)

        yield(count, total) if block_given?
      end
      total
    end
  end
end
