module ActiveMetrics
  module ConnectionAdapters
    class AbstractAdapter
      def self.create_connection(_config)
        raise NotImplementedError, "must implemented by the adapter"
      end

      def initialize(connection)
        @connection = connection
      end

      def raw_connection
        @connection
      end

      # Writes a single metric.
      #
      # @param metric [Hash] the metric to write
      #   Expected keys are :timestamp, :metric_name, and :value
      #   Also expected are either :resource or a :resource_type/:resource_id
      #     pair
      #   Optional key is :tags, which is an arbitrary set of key/value pairs.
      def write(metric)
        write_multiple(metric)
      end

      # Writes multiple metrics.
      #
      # @param metrics [Array<Hash>] the metrics to write
      #   For each metric,
      #     Expected keys are :timestamp, :metric_name, and :value
      #     Also expected are either :resource or a :resource_type/:resource_id
      #       pair
      #     Optional key is :tags, which is an arbitrary set of key/value pairs.
      def write_multiple(*_metrics)
        raise NotImplementedError, "must implemented by the adapter"
      end

      def transform_parameters(_resources, interval_name, _start_time, _end_time, rt_rows)
        rt_rows.flat_map do |ts, rt|
          rt.merge!(Metric::Processing.process_derived_columns(rt[:resource], rt, interval_name == 'realtime' ? Metric::Helper.nearest_hourly_timestamp(ts) : nil))
          rt.delete_nils
          rt_tags   = rt.slice(:capture_interval_name, :capture_interval, :resource_name).symbolize_keys
          rt_fields = rt.except(:capture_interval_name,
                                :capture_interval,
                                :resource_name,
                                :timestamp,
                                :instance_id,
                                :class_name,
                                :resource,
                                :resource_type,
                                :resource_id)

          rt_fields.map do |k, v|
            {
              :timestamp   => ts,
              :metric_name => k,
              :value       => v,
              :resource    => rt[:resource],
              :tags        => rt_tags
            }
          end
        end
      end
    end
  end
end
