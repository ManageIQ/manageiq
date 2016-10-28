module ManageIQ::Providers
  module Openshift
    class ContainerManager::RefreshParser < ManageIQ::Providers::Kubernetes::ContainerManager::RefreshParser
      def ems_inv_to_hashes(inventory)
        super(inventory)
        get_projects(inventory)
        get_routes(inventory)
        get_builds(inventory)
        get_build_pods(inventory)
        EmsRefresh.log_inv_debug_trace(@data, "data:")
        @data
      end

      def get_builds(inventory)
        process_collection(inventory["build_config"], :container_builds) { |n| parse_build(n) }

        @data[:container_builds].each do |ns|
          @data_index.store_path(:container_builds, :by_name, ns[:name], ns)
        end
      end

      def get_build_pods(inventory)
        process_collection(inventory["build"], :container_build_pods) { |n| parse_build_pod(n) }

        @data[:container_build_pods].each do |ns|
          @data_index.store_path(:container_build_pods, :by_name, ns[:name], ns)
        end
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

        labels = parse_labels(route)
        new_result.merge!(
          # TODO: persist tls
          :host_name => route.spec.try(:host),
          :labels    => labels,
          :tags      => map_labels('ContainerRoute', labels),
          :path      => route.path
        )

        new_result[:project] = @data_index.fetch_path(:container_projects, :by_name,
                                                      route.metadata["table"][:namespace])
        new_result[:container_service] = @data_index.fetch_path(:container_services, :by_namespace_and_name,
                                                                new_result[:namespace], get_service_name(route))
        new_result
      end

      def parse_build_source(source_item)
        {
          :build_source_type  => source_item.try(:type),
          :source_binary      => source_item.try(:binary).try(:asFile),
          :source_dockerfile  => source_item.try(:dockerfile),
          :source_git         => source_item.try(:git).try(:uri),
          :source_context_dir => source_item.try(:contextDir),
          :source_secret      => source_item.try(:secret).try(:name)
        }
      end

      def parse_build(build)
        new_result = parse_base_item(build)
        new_result.merge! parse_build_source(build.spec.source)
        labels = parse_labels(build)
        new_result.merge!(
          :labels                      => labels,
          :tags                        => map_labels('ContainerBuild', labels),
          :service_account             => build.spec.serviceAccount,
          :completion_deadline_seconds => build.spec.try(:completionDeadlineSeconds),
          :output_name                 => build.spec.try(:output).try(:to).try(:name)
        )

        new_result[:project] = @data_index.fetch_path(:container_projects, :by_name,
                                                      build.metadata["table"][:namespace])
        new_result
      end

      def parse_build_pod(build_pod)
        new_result = parse_base_item(build_pod)
        status = build_pod.status
        new_result.merge!(
          :labels                        => parse_labels(build_pod),
          :message                       => status[:message],
          :phase                         => status[:phase],
          :reason                        => status[:reason],
          :duration                      => status[:duration],
          :completion_timestamp          => status[:completionTimestamp],
          :start_timestamp               => status[:startTimestamp],
          :output_docker_image_reference => status[:outputDockerImageReference],
        )
        new_result[:build_config] = @data_index.fetch_path(:container_builds, :by_name,
                                                           build_pod.status.config.try(:name))
        new_result
      end
    end
  end
end
