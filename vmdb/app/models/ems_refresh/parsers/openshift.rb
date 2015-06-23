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
        process_collection(inventory["project"], :container_projects) { |n| parse_project(n) }
      end

      def parse_project(project)
        new_result = parse_base_item(project)
        new_result.except!(:namespace)
        new_result.merge!(
            :labels       => parse_labels(project),
            :display_name => project.displayName
        )
        new_result
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
        new_result
      end
    end
  end
end
