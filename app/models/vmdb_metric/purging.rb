module VmdbMetric::Purging
  extend ActiveSupport::Concern
  include PurgingMixin

  module ClassMethods
    def purge_date(interval)
      type  = "keep_#{interval}_metrics".to_sym
      value = VMDB::Config.new("vmdb").config.fetch_path(:database, :metrics_history, type)
      value = value.to_i.days if value.kind_of?(Fixnum) # Default unit is days
      value = value.to_i_with_method.seconds.ago.utc unless value.nil?
      value
    end

    def purge_all_timer
      purge_hourly_timer
      purge_daily_timer
    end

    def purge_daily_timer(ts = nil)
      interval = "daily"
      ts ||= purge_date(interval) || 6.months.ago.utc
      purge_timer(ts, interval)
    end

    def purge_hourly_timer(ts = nil)
      interval = "hourly"
      ts ||= purge_date(interval) || 6.months.ago.utc
      purge_timer(ts, interval)
    end

    def purge_timer(value, interval)
      MiqQueue.put_unless_exists(
        :class_name    => name,
        :method_name   => "purge_by_date",
        :role          => "database_operations",
        :queue_name    => "generic",
        :state         => ["ready", "dequeue"],
        :args_selector => ->(args) { args.kind_of?(Array) && args.last == interval }
      ) do |_msg, find_options|
        find_options.merge(:args => [value, interval])
      end
    end

    def purge_window_size
      VMDB::Config.new("vmdb").config.fetch_path(:database, :metrics_history, :purge_window_size) || 10000
    end

    def purge_count(mode, value, interval)
      send("purge_count_by_#{mode}", value, interval)
    end

    # deprecated, calling purge_by_date directly
    def purge(mode, value, interval, window = nil, &block)
      send("purge_by_#{mode}", value, interval, window, &block)
    end

    private

    #
    # By Date
    #

    # darn - an extra parameter than typical purge_scope
    def purge_scope(older_than, interval)
      where(:capture_interval_name => interval).where(arel_table[:timestamp].lt(older_than))
    end

    def purge_count_by_date(older_than, interval)
      purge_scope(older_than, interval).count
    end

    def purge_by_date(older_than, interval, window = nil, &block)
      _log.info("Purging #{interval} metrics older than [#{older_than}]...")

      scope = purge_scope(older_than, interval)
      total = purge_in_batches(scope, window || purge_window_size, &block)

      _log.info("Purging #{interval} metrics older than [#{older_than}]...Complete - Deleted #{total} records")
      total
    end
  end
end
