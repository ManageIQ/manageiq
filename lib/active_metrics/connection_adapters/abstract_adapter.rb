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
      def write(_metric)
        raise NotImplementedError, "must implemented by the adapter"
      end

      # Writes multiple metrics.
      #
      # @param metrics [Array<Hash>] the metrics to write
      #   For each metric,
      #     Expected keys are :timestamp, :metric_name, and :value
      #     Also expected are either :resource or a :resource_type/:resource_id
      #       pair
      #     Optional key is :tags, which is an arbitrary set of key/value pairs.
      def write_multiple(*metrics)
        # Default naive implementation. Can be overridden by the adapter.
        metrics.flatten!
        metrics.each { |metric| write(metric) }
      end
    end
  end
end
