class ManageIQ::Providers::Azure::CloudManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  INTERVAL_1_MINUTE = "PT1M".freeze

  # Linux, Windows counters
  CPU_METERS     = ["\\Processor(_Total)\\% Processor Time", "\\Processor\\PercentProcessorTime"].freeze
  NETWORK_METERS = ["\\NetworkInterface\\BytesTotal"].freeze # Linux (No windows counter available)
  MEMORY_METERS  = ["\\Memory\\PercentUsedMemory", "\\Memory\\% Committed Bytes In Use"].freeze
  DISK_METERS    = ["\\PhysicalDisk\\BytesPerSecond",
                    "\\PhysicalDisk(_Total)\\Disk Read Bytes/sec", # Windows
                    "\\PhysicalDisk(_Total)\\Disk Write Bytes/sec"].freeze # Windows

  COUNTER_INFO = [
    {
      :native_counters       => CPU_METERS,
      :calculation           => ->(stat) { stat.first },
      :vim_style_counter_key => "cpu_usage_rate_average"
    },
    {
      :native_counters       => NETWORK_METERS,
      :calculation           => ->(stat) { stat.first / 1.kilobyte },
      :vim_style_counter_key => "net_usage_rate_average",
    },
    {
      :native_counters       => MEMORY_METERS,
      :calculation           => ->(stat) { stat.first },
      :vim_style_counter_key => "mem_usage_absolute_average",
    },
    {
      :native_counters       => DISK_METERS,
      :calculation           => ->(stat) { stat.sum / 1.kilobyte },
      :vim_style_counter_key => "disk_usage_rate_average",
    }
  ].freeze

  COUNTER_NAMES = COUNTER_INFO.flat_map { |i| i[:native_counters] }.uniq.to_set.freeze

  VIM_STYLE_COUNTERS = {
    "cpu_usage_rate_average"      => {
      :counter_key           => "cpu_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "percent",
      :capture_interval_name => "realtime"
    },
    "mem_usage_absolute_average"  => {
      :counter_key           => "mem_usage_absolute_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "percent",
      :capture_interval_name => "realtime"
    },
    "net_usage_rate_average"      => {
      :counter_key           => "net_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    },
    "disk_usage_rate_average"     => {
      :counter_key           => "disk_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    },
  }.freeze

  def perf_collect_metrics(interval_name, start_time = nil, end_time = nil)
    raise "No EMS defined" if target.ext_management_system.nil?

    log_header = "[#{interval_name}] for: [#{target.class.name}], [#{target.id}], [#{target.name}]"

    end_time   = (end_time || Time.now).utc
    start_time = (start_time || end_time - 4.hours).utc # 4 hours for symmetry with VIM

    begin
      # This is just for consistency, to produce a :connect benchmark
      Benchmark.realtime_block(:connect) {}
      target.ext_management_system.with_provider_connection do |conn|
        with_metrics_services(conn) do |metrics_conn, storage_conn|
          perf_capture_data_azure(metrics_conn, storage_conn, start_time, end_time)
        end
      end
    rescue Exception => err
      _log.error("#{log_header} Unhandled exception during perf data collection: [#{err}], class: [#{err.class}]")
      _log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      _log.log_backtrace(err)
      raise
    end
  end

  private

  def with_metrics_services(connection)
    metrics_conn = Azure::Armrest::Insights::MetricsService.new(connection)
    storage_conn = Azure::Armrest::StorageAccountService.new(connection)

    yield metrics_conn, storage_conn
  end

  def storage_accounts(storage_account_service)
    @storage_accounts ||= storage_account_service.list_all
  end

  def perf_capture_data_azure(metrics_conn, storage_conn, start_time, end_time)
    start_time -= 1.minutes # Get one extra minute so we can build the 20-second intermediate values

    counters                = get_counters(metrics_conn)
    metrics_by_counter_name = metrics_by_counter_name(storage_conn, counters, start_time, end_time)
    counter_values_by_ts    = counter_values_by_timestamp(metrics_by_counter_name)

    counters_by_id              = {target.ems_ref => VIM_STYLE_COUNTERS}
    counter_values_by_id_and_ts = {target.ems_ref => counter_values_by_ts}
    return counters_by_id, counter_values_by_id_and_ts
  end

  def counter_values_by_timestamp(metrics_by_counter_name)
    counter_values_by_ts = {}
    COUNTER_INFO.each do |i|
      timestamps = i[:native_counters].flat_map do |c|
        metrics_by_counter_name[c].keys unless metrics_by_counter_name[c].nil?
      end.uniq.compact.sort

      timestamps.each_cons(2) do |last_ts, ts|
        metrics = i[:native_counters].collect { |c| metrics_by_counter_name.fetch_path(c, ts) }
        value = i[:calculation].call(metrics.compact)

        # For (temporary) symmetry with VIM API we create 20-second intervals.
        (last_ts + 20.seconds..ts).step_value(20.seconds).each do |inner_ts|
          counter_values_by_ts.store_path(inner_ts.iso8601, i[:vim_style_counter_key], value)
        end
      end
    end
    counter_values_by_ts
  end

  def metrics_by_counter_name(storage_conn, counters, start_time, end_time)
    counters.each_with_object({}) do |c, h|
      metrics = h[c.name.value] = {}

      raw_metrics, _timings = Benchmark.realtime_block(:capture_counter_values) do
        raw_metrics_for_counter(storage_conn, c, start_time, end_time)
      end

      raw_metrics.each { |m| metrics[Time.parse(m._timestamp)] = m.average }
    end
  end

  def raw_metrics_for_counter(storage_conn, counter, start_time, end_time)
    # TODO: We should really find the availabilities that
    #       a) match the time range
    #       b) are other sizes than 1-minute time grains
    # TODO: This should live in the azure-armrest gem as a general method for
    #       capturing metrics for a target.
    availability = counter.metric_availabilities.detect { |ma| ma.time_grain == INTERVAL_1_MINUTE }
    return [] if availability.nil?

    table_name = availability.location.table_info.last.try(:table_name)
    return [] if table_name.nil?

    endpoint      = availability.location.table_endpoint
    partition_key = availability.location.partition_key

    storage_acct_name = URI.parse(endpoint).host.split('.').first
    storage_account   = storage_accounts(storage_conn).find { |account| account.name == storage_acct_name }
    storage_key       = storage_conn.list_account_keys(storage_account.name, storage_account.resource_group).fetch('key1')

    # TODO: The following needs to pass :all => true for proper paging in case
    #       the time range is > 1000 metrics, but there seems to be a bug in
    #       continuation tokens when doing this.
    storage_account.table_data(table_name, storage_key,
      :filter => "PartitionKey eq '#{partition_key}' and CounterName eq '#{counter.name.value}' and Timestamp ge datetime'#{start_time.iso8601}' and Timestamp le datetime'#{end_time.iso8601}'",
      :select => "Timestamp,TIMESTAMP,Average"
    )
  end

  def get_counters(metrics_conn)
    counters, _timings = Benchmark.realtime_block(:capture_counters) do
      metrics_conn
        .list('Microsoft.Compute', 'virtualMachines', target.name, target.resource_group)
        .select { |m| m.name.value.in?(COUNTER_NAMES) }
    end
    counters
  end
end
