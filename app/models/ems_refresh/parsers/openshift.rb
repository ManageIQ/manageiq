module EmsRefresh
  module Parsers
    class Openshift < Kubernetes
      def ems_inv_to_hashes(inventory)
        super(inventory)
        get_projects(inventory)
        get_routes(inventory)
        EmsRefresh.log_inv_debug_trace(@data, "data:")
        @data
      end

      def get_routes(inventory)
        process_collection(inventory["route"], :container_routes) { |n| parse_route(n) }
      end

      def get_projects(inventory)
        inventory["project"].each { |item| parse_project(item) }

        @data[:container_projects].each do |ns|
          @data_index.store_path(:container_projects, :by_name, ns[:name], ns)
        end
      end

      def parse_project(project_item)
        project = @data_index.fetch_path(:container_projects, :by_name, project_item.metadata.name)
        project.merge!(:display_name => project_item.metadata.annotations['openshift.io/display-name']) unless
            project_item.metadata.annotations.nil?
      end

      def get_service_name(route)
        route.spec.try(:to).try(:kind) == 'Service' ? route.spec.try(:to).try(:name) : nil
      end

      def parse_route(route)
        new_result = parse_base_item(route)

        new_result.merge!(
          # TODO: persist tls
          :host_name    => route.spec.try(:host),
          :labels       => parse_labels(route),
          :path         => route.path
        )

        new_result[:project] = @data_index.fetch_path(:container_projects, :by_name,
                                                      route.metadata["table"][:namespace])
        new_result[:container_service] = @data_index.fetch_path(:container_services, :by_namespace_and_name,
                                                                new_result[:namespace], get_service_name(route))
        new_result
      end
    end
  end
end
