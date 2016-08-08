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
    end
  end
end
