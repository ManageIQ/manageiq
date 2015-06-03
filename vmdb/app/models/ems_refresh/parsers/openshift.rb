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
        project.merge!(:display_name => project_item.metadata.annotations.displayName) unless
            project_item.metadata.annotations.nil?
      end

      def parse_route(route)
        new_result = parse_base_item(route)

        new_result.merge!(
            # TODO: persist tls
            :host_name    => route.host,
            :labels       => parse_labels(route),
            # TODO: this part needs to be modified to service_id instead
            :service_name => route.serviceName,
            :path         => route.path
        )

        new_result[:project] = @data_index.fetch_path(:container_projects, :by_name,
                                                      route.metadata["table"][:namespace])
        new_result
      end
    end
  end
end
