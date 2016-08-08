require 'active_metrics/connection_adapters/abstract_adapter'

module ActiveMetrics
  module ConnectionAdapters
    class InfluxdbAdapter < AbstractAdapter
      SERIES    = "metrics".freeze
      PRECISION = "ms".freeze

      def self.create_connection(config)
        db = config[:database]

        require 'influxdb'
        InfluxDB::Client.new(db, :time_precision => PRECISION, :retry => 10).tap do |client|
          client.create_database(db) unless client.list_databases.include?(db)
        end
      end

      def write_multiple(*metrics)
        metrics.flatten!
        points = metrics.map { |metric| build_point(metric) }
        raw_connection.write_points(points)
        metrics
      end

      private

      def build_point(timestamp:, metric_name:, value:, resource: nil, resource_type: nil, resource_id: nil, tags: {})
        if resource.nil? && (resource_type.nil? || resource_id.nil?)
          raise ArgumentError, "missing resource or resource_type/resource_id pair"
        end

        {
          :series    => SERIES,
          :timestamp => (timestamp.to_f * 1000).to_i, # ms precision
          :values    => { metric_name.to_sym => value },
          :tags      => tags.symbolize_keys.merge(
            :resource_type => resource ? resource.class.base_class.name : resource_type,
            :resource_id   => resource ? resource.id : resource_id
          ),
        }
      end
    end
  end
end
