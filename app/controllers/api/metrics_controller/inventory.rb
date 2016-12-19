module Api
  class MetricsController
    class Inventory
      def providers(ems)
        ems.present? ? 1 : ManageIQ::Providers::ContainerManager.count
      end

      def nodes(ems)
        ems.present? ? ems.container_nodes.count : ContainerNode.count
      end

      def containers(ems)
        ems.present? ? ems.containers.count : Container.where.not(:ext_management_system => nil).count
      end

      def registries(ems)
        ems.present? ? ems.container_image_registries.count : ContainerImageRegistry.count
      end

      def projects(ems)
        ems.present? ? ems.container_projects.count : ContainerProject.where.not(:ext_management_system => nil).count
      end

      def pods(ems)
        ems.present? ? ems.container_groups.count : ContainerGroup.where.not(:ext_management_system => nil).count
      end

      def services(ems)
        ems.present? ? ems.container_services.count : ContainerService.count
      end

      def images(ems)
        ems.present? ? ems.container_images.count : ContainerImage.where.not(:ext_management_system => nil).count
      end

      def routes(ems)
        routes_count(ems)
      end

      def self.keys
        %w(
          providers
          nodes
          containers
          registries
          projects
          pods
          services
          images
          routes
        ).freeze
      end

      def self.metrics
        providers = ManageIQ::Providers::ContainerManager.all.map(&:name)

        keys.flat_map do |m|
          [{:id => "evm/local/#{m}"}] +
            providers.map { |k| {:id => "provider/#{k}/#{m}"} }
        end
      end

      def self.data_for_key_provider(name, metric_name)
        provider = ExtManagementSystem.find_by(:name => name)

        data = MetricsController::Inventory.new
        [{:timestamp => 0.hours.ago.to_i * 1000, :value => data.send(metric_name, provider)}]
      end

      def self.data_for_key_evm(_name, metric_name)
        data = MetricsController::Inventory.new
        [{:timestamp => 0.hours.ago.to_i * 1000, :value => data.send(metric_name, nil)}]
      end

      private

      def routes_count(ems)
        if ems.present?
          ems.respond_to?(:container_routes) ? ems.container_routes.count : 0 # ems might not have routes
        else
          ContainerRoute.count
        end
      end
    end
  end
end
