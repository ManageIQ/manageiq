module ManageIQ::Providers
  class Kubernetes::ContainerManager::VimPerformanceAnalysis
    class AvgMetricsHash < Hash
      def method_missing(method_sym, *_args, &_block)
        fetch(method_sym) { |_key| super }
      end

      def respond_to?(method_name, include_private = false)
        key?(method_name) || super
      end

      def respond_to_missing?(*_args)
        true
      end
    end

    def self.collect_metrics(obj, start_time, end_time, interval)
      client = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::CaptureContext.new(
        obj, start_time, end_time, interval
      )

      client.collect_metrics
      total_memory = client.total_memory
      total_cpu_time = client.total_cpu_time

      results = {}
      client.ts_values.each do |k, v|
        values = v.symbolize_keys

        # Add missing fields
        values[:timestamp] = k
        values[:max_mem_usage_absolute_average] = values[:mem_usage_absolute_average]
        values[:max_cpu_usage_rate_average] = values[:cpu_usage_rate_average]
        values[:total_memory] = total_memory
        values[:total_cpu_time] = total_cpu_time

        unless values[:mem_usage_absolute_average].nil?
          values[:derived_memory_used] = total_memory * values[:mem_usage_absolute_average] / 100
        end
        unless values[:cpu_usage_rate_average].nil?
          values[:cpu_usagemhz_rate_average] = total_cpu_time * values[:cpu_usage_rate_average] / 100
        end

        results[k] = values
      end

      results
    end

    def self.reduce_metrics(value, new_value)
      return new_value if value.nil?

      {
        :cpu_usagemhz_rate_average      => value[:cpu_usagemhz_rate_average] + new_value[:cpu_usagemhz_rate_average],
        :derived_memory_used            => value[:derived_memory_used] + new_value[:derived_memory_used],
        :net_usage_rate_average         => value[:net_usage_rate_average] + new_value[:net_usage_rate_average],
        :max_mem_usage_absolute_average => [
          value[:max_mem_usage_absolute_average],
          new_value[:max_mem_usage_absolute_average]
        ].max,
        :max_cpu_usage_rate_average     => [
          value[:max_cpu_usage_rate_average],
          new_value[:max_cpu_usage_rate_average]
        ].max,
        :total_memory                   => value[:total_memory] + new_value[:total_memory],
        :total_cpu_time                 => value[:total_cpu_time] + new_value[:total_cpu_time]
      }
    end

    def self.avg_metrics(values)
      results = []
      values.each do |k, v|
        result = AvgMetricsHash.new
        v.each { |key, value| result[key.to_sym] = value }

        result[:timestamp] = k
        result[:mem_usage_absolute_average] = 100.0 * result[:derived_memory_used] / result[:total_memory]
        result[:cpu_usage_rate_average] = 100.0 * result[:cpu_usagemhz_rate_average] / result[:total_cpu_time]
        results << result
      end
      results
    end

    def self.find_perf_for_time_period(obj, interval_name, options = {})
      # Options
      #   :days        => Number of days back from end_date. Used only if start_date not passed
      #   :start_date  => Starting date
      #   :end_date    => Ending date
      #   :conditions  => ActiveRecord find conditions
      time_range = Metric::Helper.time_range_from_hash(options)
      start_time = time_range.first
      end_time = time_range.last
      interval = {
        :hourly => 60 * 60,
        :daily  => 24 * 60 * 60
      }[interval_name.to_sym]

      objs_list = if obj.class.name == "ContainerProject"
                    obj.container_groups
                  elsif obj.class.name == "ManageIQ::Providers::Openshift::ContainerManager"
                    obj.container_nodes
                  else
                    [obj]
                  end

      values = {}
      objs_list.each do |o|
        v = collect_metrics(o, start_time, end_time, interval)
        v.keys.each do |k|
          values[k] = reduce_metrics(values[k], v[k])
        end
      end

      avg_metrics(values)
    end
  end
end
