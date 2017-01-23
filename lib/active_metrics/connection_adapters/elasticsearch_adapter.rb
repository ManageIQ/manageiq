require 'active_metrics/connection_adapters/abstract_adapter'

module ActiveMetrics
  module ConnectionAdapters
    class ElasticsearchAdapter < AbstractAdapter
      INDEX = "manageiq".freeze
      TYPE  = "metrics".freeze

      def self.create_connection(_config)
        require 'elasticsearch'
        Elasticsearch::Client.new # TODO: Use config parameters
      end

      def write_multiple(*metrics)
        metrics.flatten!

        points = metrics.collect { |metric| build_point(metric) }
        raw_connection.bulk(:index => INDEX, :type => TYPE, :body => points)

        metrics
      end

      private

      def build_point(timestamp:, metric_name:, value:, resource: nil, resource_type: nil, resource_id: nil, tags: {})
        if resource.nil? && (resource_type.nil? || resource_id.nil?)
          raise ArgumentError, "missing resource or resource_type/resource_id pair"
        end

        {
          :index => {
            :data => {
              :timestamp         => (timestamp.to_f * 1000).to_i, # ms precision
              metric_name.to_sym => value,
              :tags              => tags.symbolize_keys.merge(
                :resource_type => resource ? resource.class.base_class.name : resource_type,
                :resource_id   => resource ? resource.id : resource_id
              )
            }
          }
        }
      end
    end
  end
end
