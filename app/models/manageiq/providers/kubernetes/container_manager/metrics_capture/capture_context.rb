class ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture
  class CaptureContext
    include ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClientMixin

    def initialize(target, start_time, end_time, interval)
      @target = target
      @start_time = start_time || 15.minutes.ago.beginning_of_minute.utc
      @end_time = end_time
      @interval = interval
      @tenant = target.try(:container_project).try(:name) || '_system'
      @ext_management_system = @target.ext_management_system || @target.try(:old_ext_management_system)
      @ts_values = Hash.new { |h, k| h[k] = {} }
      @metrics = []

      if @target.respond_to?(:hardware)
        hardware = @target.hardware
      else
        hardware = @target.try(:container_node).try(:hardware)
      end

      @node_cores = hardware.try(:cpu_total_cores)
      @node_memory = hardware.try(:memory_mb)

      validate_target
    end

    def collect_metrics
      case @target
      when ContainerNode  then collect_node_metrics
      when Container      then collect_container_metrics
      when ContainerGroup then collect_group_metrics
      else raise TargetValidationError, "Validation error: unknown target"
      end
    end

    def ts_values
      # Filtering out entries that are not containing all the metrics.
      # This generally happens because metrics are collected at slightly
      # different times and could produce entries that are incomplete.
      @ts_values.select { |_, v| @metrics.all? { |k| v.key?(k) } }
    end

    private

    CPU_NANOSECONDS = 1e09

    def target_name
      "#{@target.class.name.demodulize}(#{@target.id})"
    end

    def validate_target
      raise TargetValidationError, "Validation error: ems not defined"    unless @ext_management_system
      raise TargetValidationError, "Validation error: cores not defined"  unless @node_cores.to_i > 0
      raise TargetValidationError, "Validation error: memory not defined" unless @node_memory.to_i > 0
    end

    def collect_node_metrics
      cpu_resid = "machine/#{@target.name}/cpu/usage"
      process_cpu_counters_rate(fetch_counters_rate(cpu_resid))

      mem_resid = "machine/#{@target.name}/memory/usage"
      process_mem_gauges_data(fetch_gauges_data(mem_resid))

      net_resid = "machine/#{@target.name}/network"
      net_counters = [fetch_counters_rate("#{net_resid}/tx"),
                      fetch_counters_rate("#{net_resid}/rx")]

      process_net_counters_rate(compute_summation(net_counters))
    end

    def collect_container_metrics
      group_id = @target.container_group.ems_ref

      cpu_resid = "#{@target.name}/#{group_id}/cpu/usage"
      process_cpu_counters_rate(fetch_counters_rate(cpu_resid))

      mem_resid = "#{@target.name}/#{group_id}/memory/usage"
      process_mem_gauges_data(fetch_gauges_data(mem_resid))
    end

    def collect_group_metrics
      group_id = @target.ems_ref

      cpu_counters = @target.containers.collect do |c|
        fetch_counters_rate("#{c.name}/#{group_id}/cpu/usage")
      end
      process_cpu_counters_rate(compute_summation(cpu_counters))

      mem_gauges = @target.containers.collect do |c|
        fetch_gauges_data("#{c.name}/#{group_id}/memory/usage")
      end
      process_mem_gauges_data(compute_summation(mem_gauges))

      net_resid = "pod/#{group_id}/network"
      net_counters = [fetch_counters_rate("#{net_resid}/tx"),
                      fetch_counters_rate("#{net_resid}/rx")]
      process_net_counters_rate(compute_summation(net_counters))
    end

    def fetch_counters_rate(resource)
      compute_derivative(fetch_counters_data(resource))
    end

    def fetch_counters_data(resource)
      sort_and_normalize(
        hawkular_client.counters.get_data(
          resource,
          :starts         => (@start_time - @interval).to_i.in_milliseconds,
          :bucketDuration => "#{@interval}s"))
    rescue SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
      raise CollectionFailure, e.message
    end

    def fetch_gauges_data(resource)
      sort_and_normalize(
        hawkular_client.gauges.get_data(
          resource,
          :starts         => @start_time.to_i.in_milliseconds,
          :bucketDuration => "#{@interval}s"))
    rescue SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
      raise CollectionFailure, e.message
    end

    def process_cpu_counters_rate(counters_rate)
      @metrics |= ['cpu_usage_rate_average'] if counters_rate.length > 0
      total_cpu_time = @node_cores * CPU_NANOSECONDS * @interval
      counters_rate.each do |x|
        timestamp = Time.at(x['start'] / 1.in_milliseconds).utc
        avg_usage = (x['avg'] * 100.0) / total_cpu_time
        @ts_values[timestamp]['cpu_usage_rate_average'] = avg_usage
      end
    end

    def process_mem_gauges_data(gauges_data)
      @metrics |= ['mem_usage_absolute_average'] if gauges_data.length > 0
      gauges_data.each do |x|
        timestamp = Time.at(x['start'] / 1.in_milliseconds).utc
        avg_usage = (x['avg'] / 1.megabytes) * 100.0 / @node_memory
        @ts_values[timestamp]['mem_usage_absolute_average'] = avg_usage
      end
    end

    def process_net_counters_rate(counters_rate)
      @metrics |= ['net_usage_rate_average'] if counters_rate.length > 0
      counters_rate.each do |x|
        timestamp = Time.at(x['start'] / 1.in_milliseconds).utc
        avg_usage_kb = x['avg'] / (1.kilobyte.to_f * @interval)
        @ts_values[timestamp]['net_usage_rate_average'] = avg_usage_kb
      end
    end

    def compute_summation(data)
      ts_data = Hash.new { |h, k| h[k] = [] }

      data.flatten.each { |x| ts_data[x['start']] << x }
      ts_data.delete_if { |_k, v| v.length != data.length }

      ts_data.keys.sort.map do |k|
        ts_data[k].inject do |sum, n|
          # Add min, median, max, percentile95th, etc. if needed
          {
            'start' => k,
            'end'   => [sum['end'], n['end']].max,
            'avg'   => sum['avg'] + n['avg']
          }
        end
      end
    end

    def sort_and_normalize(data)
      # Sorting and removing last entry because always incomplete
      # as it's still in progress.
      norm_data = (data.sort_by { |x| x['start'] }).slice(0..-2)
      norm_data.reject { |x| x.values.include?('NaN') || x['empty'] == true }
    end

    def compute_derivative(counters)
      counters.each_cons(2).map do |prv, n|
        # Add min, median, max, percentile95th, etc. if needed
        {
          'start' => n['start'],
          'end'   => n['end'],
          'avg'   => n['avg'] - prv['avg']
        }
      end
    end
  end
end
