module Api
  class MetricsController
    class Rollups
      def self.data_for_key_machine(name, metric_name, starts, ends)
        node = ContainerNode.find_by(:name => name)

        metrics = node.metric_rollups.where(:timestamp => starts..ends, :capture_interval_name => "hourly")
        metrics.order(:timestamp).map { |m| {:timestamp => m.timestamp.to_i * 1000, :value => m[metric_name]} }
      end

      def self.data_for_key_provider(name, metric_name, starts, ends)
        provider = ExtManagementSystem.find_by(:name => name)

        metrics = provider.metric_rollups.where(:timestamp => starts..ends, :capture_interval_name => "hourly")
        metrics.order(:timestamp).map { |m| {:timestamp => m.timestamp.to_i * 1000, :value => m[metric_name]} }
      end

      def self.data_for_key_evm(_name, metric_name, starts, ends)
        metrics = MetricRollup.where(:resource_type         => "ExtManagementSystem",
                                     :capture_interval_name => "hourly",
                                     :timestamp             => starts..ends).group(:timestamp).order(:timestamp)
        metrics.sum(metric_name.to_sym).map { |k, v| {:timestamp => k.to_i * 1000, :value => v} }
      end

      def self.keys
        %w(
          cpu_usage_rate_average
          mem_usage_absolute_average
          net_usage_rate_average
          derived_memory_available
          derived_memory_used
          stat_container_group_create_rate
          stat_container_group_delete_rate
          stat_container_image_registration_rate
        ).freeze
      end

      def self.metrics
        providers = ManageIQ::Providers::ContainerManager.all.map(&:name)
        nodes     = ContainerNode.all.map(&:name)

        keys.flat_map do |m|
          [{:id => "evm/local/#{m}"}] +
            nodes.map     { |k| {:id => "machine/#{k}/#{m}"} } +
            providers.map { |k| {:id => "provider/#{k}/#{m}"} }
        end
      end
    end
  end
end
