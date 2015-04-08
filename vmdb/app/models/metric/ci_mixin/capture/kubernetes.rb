module Metric::CiMixin::Capture::Kubernetes
  INFLUXDB_TIMEFMT = '%Y-%m-%d %H:%M:%S'
  INFLUXDB_TIME_GROUP = '20s'

  def perf_collect_metrics_kubernetes(interval_name, start_time = nil,
                                      end_time = nil)
    start_time ||= 15.minutes.ago.utc

    $log.info("#{log_header} Collecting Kubernetes metrics - interval: " \
              "[#{interval_name}], start_time: [#{start_time}], " \
              "end_time: [#{end_time}]")

    influxdb_options = {
      :use_ssl    => ext_management_system.api_endpoint.scheme == 'https',
      # TODO: support real authentication using certificates
      :verify_ssl => false,
      :host       => ext_management_system.hostname,
      :port       => ext_management_system.port,
      # TODO: service name should come from the db
      :path       => '/api/v1beta3/proxy/namespaces/default/services' \
                     '/monitoring-influxdb'
    }

    require 'influxdb'
    influxdb = InfluxDB::Client.new('k8s', influxdb_options)

    counters, = Benchmark.realtime_block(:collect_data) do
      collect_metrics(influxdb, start_time)
    end

    [
      {ems_ref => Metric::Capture::Kubernetes::VIM_STYLE_COUNTERS},
      {ems_ref => counters}
    ]
  end

  private

  def log_header
    "MIQ(#{self.class.name}.perf_collect_metrics_kubernetes) id: [#{id}] " \
    "name: [#{name}]"
  end

  METRIC_KEYS = [
    'cpu_usage_rate_average',
    'mem_usage_absolute_average',
    'net_usage_rate_average'
  ]

  def collect_metrics(influxdb, start_time)
    values_by_ts = Hash.new { |h, k| h[k] = {} }

    case self
    when ContainerNodeKubernetes
      where = "container_name = '/' and hostname = '#{name}'"
      grpby = ""
      logical_cpus = hardware.logical_cpus
      memory_cpu = hardware.memory_cpu
    when ContainerKubernetes
      where = "container_name = '#{name}' and pod_id = '#{pod_uid}'"
      grpby = ""
      logical_cpus = container_node.hardware.logical_cpus
      memory_cpu = container_node.hardware.memory_cpu
    when ContainerGroupKubernetes
      where = "pod_id = '#{pod_uid}'"
      grpby = ",container_name"
      logical_cpus = container_node.hardware.logical_cpus
      memory_cpu = container_node.hardware.memory_cpu
    else
      raise NotImplementedError, "Cannot collect for #{self.class.name}"
    end

    collect_cpu_rate(influxdb, where, grpby, start_time) do |ts, value|
      avg_pct = value.to_d * 100.0 / logical_cpus
      values_by_ts[ts]['cpu_usage_rate_average'] ||= 0
      values_by_ts[ts]['cpu_usage_rate_average'] += avg_pct
    end

    collect_memory_usage(influxdb, where, grpby, start_time) do |ts, value|
      avg_pct = value.to_d * 100.0 / memory_cpu
      values_by_ts[ts]['mem_usage_absolute_average'] ||= 0
      values_by_ts[ts]['mem_usage_absolute_average'] += avg_pct
    end

    collect_network_rate(influxdb, where, grpby, start_time) do |ts, value|
      values_by_ts[ts]['net_usage_rate_average'] ||= 0 # Kbps
      values_by_ts[ts]['net_usage_rate_average'] += value # Kbps
    end

    # Filter out entries that don't have all the metrics
    values_by_ts.select! { |_, v| METRIC_KEYS.all? { |k| !v[k].nil? } }

    values_by_ts
  end

  def collect_cpu_rate(influxdb, where, grpby, start_time)
    metrics = influxdb.query(
      "select derivative(value) as cpu_usage_ns " \
      "from \"cpu/usage_ns_cumulative\" " \
      "where time > #{start_time.utc.to_i}s " \
      "and #{where} group by time(#{INFLUXDB_TIME_GROUP})#{grpby} " \
      "order asc")

    metrics.fetch('cpu/usage_ns_cumulative', []).each do |stats|
      next if stats['time'].nil? || stats['cpu_usage_ns'].nil?
      cpu_time_in_seconds = stats['cpu_usage_ns'] * 1.0e-09
      yield [Time.at(stats['time']).utc, cpu_time_in_seconds]
    end
  end

  def collect_memory_usage(influxdb, where, grpby, start_time)
    metrics = influxdb.query(
      "select mean(value) as mem_usage_bytes " \
      "from \"memory/usage_bytes_gauge\" " \
      "where time > #{start_time.utc.to_i}s " \
      "and #{where} group by time(#{INFLUXDB_TIME_GROUP})#{grpby} " \
      "order asc")

    metrics.fetch('memory/usage_bytes_gauge', []).each do |stats|
      next if stats['time'].nil? || stats['mem_usage_bytes'].nil?
      usage_megabytes = (stats['mem_usage_bytes'].to_d / 1.megabyte).round
      yield [Time.at(stats['time']).utc, usage_megabytes]
    end
  end

  def process_network_rate(metrics, table_name)
    Hash[metrics.fetch(table_name, []).map do |stats|
      next if stats['time'].nil? || stats['net_usage_bytes'].nil?
      rate_kilobytes = (stats['net_usage_bytes'].to_d / 1.kilobyte).round
      [Time.at(stats['time']).utc, rate_kilobytes]
    end]
  end

  def collect_network_rate(influxdb, where, grpby, start_time)
    tx_table = 'network/tx_bytes_cumulative'
    rx_table = 'network/rx_bytes_cumulative'

    metrics = influxdb.query(
      "select derivative(value) as net_usage_bytes " \
      "from \"#{tx_table}\", \"#{rx_table}\" " \
      "where time > #{start_time.utc.to_i}s "\
      "and #{where} group by time(#{INFLUXDB_TIME_GROUP})#{grpby} " \
      "order asc"
    )

    tx_bytes = process_network_rate(metrics, tx_table)
    rx_bytes = process_network_rate(metrics, rx_table)

    (tx_bytes.keys & rx_bytes.keys).sort.each do |ts|
      yield [ts, tx_bytes[ts] + rx_bytes[ts]]
    end
  end
end
