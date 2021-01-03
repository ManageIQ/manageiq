class MiqWorker
  module ContainerCommon
    extend ActiveSupport::Concern

    def configure_worker_deployment(definition, replicas = 0)
      definition[:spec][:replicas] = replicas
      definition[:spec][:template][:spec][:terminationGracePeriodSeconds] = self.class.worker_settings[:stopping_timeout].seconds

      if MiqServer.my_zone != "default"
        definition[:spec][:template][:spec][:nodeSelector] = zone_selector
      end

      container = definition[:spec][:template][:spec][:containers].first

      if container_image_tag.include?("latest")
        container[:imagePullPolicy] = "Always"
      else
        container[:imagePullPolicy] = "IfNotPresent"
      end

      container[:image] = container_image
      container[:env] << {:name => "WORKER_CLASS_NAME", :value => self.class.name}
      container[:env] << {:name => "BUNDLER_GROUPS", :value => self.class.bundler_groups.join(",")}
      container[:resources] = resource_constraints
    end

    def scale_deployment
      ContainerOrchestrator.new.scale(worker_deployment_name, self.class.workers)
      delete_container_objects if self.class.workers.zero?
    end

    def patch_deployment
      # Start with just resource constraints. Perhaps the livenessProbe, readinessProbe,
      # and various timeouts such as terminationGracePeriodSeconds, could be patched later on.
      # Note, we need to specify the name and image as they're required fields for the API to 'find'
      # the correct container, even if we only ever have one.
      data = {
        :spec => {
          :template => {
            :spec => {
              :containers => [
                {
                  :name      => worker_deployment_name,
                  :image     => container_image,
                  :resources => resource_constraints
                }
              ]
            }
          }
        }
      }
      ContainerOrchestrator.new.patch_deployment(worker_deployment_name, data)
    end

    def zone_selector
      {"#{Vmdb::Appliance.PRODUCT_NAME.downcase}/zone-#{MiqServer.my_zone}" => "true"}
    end

    def container_image
      ENV["BASE_WORKER_IMAGE"] || default_image
    end

    def default_image
      "#{container_image_namespace}/#{container_image_name}:#{container_image_tag}"
    end

    def resource_constraints
      return {} unless Settings.server.worker_monitor.enforce_resource_constraints

      mem_limit = self.class.worker_settings[:memory_threshold]
      cpu_limit = self.class.worker_settings[:cpu_threshold_percent]

      # If request > limit, kubeclient will raise each time we try
      # [Kubeclient::HttpError]: Deployment.apps "1-schedule" is invalid: spec.template.spec.containers[0].resources.requests: Invalid value: "567Mi": must be less than or equal to memory limit
      mem_request   = self.class.worker_settings[:memory_request]
      cpu_request   = self.class.worker_settings[:cpu_request_percent]

      raise ArgumentError, "cpu_request_percent cannot exceed cpu_threshold_percent" if (cpu_request || 0) > (cpu_limit || Float::INFINITY)
      raise ArgumentError, "memory_request cannot exceed memory_threshold"           if (mem_request || 0) > (mem_limit || Float::INFINITY.megabytes)

      {}.tap do |h|
        h.store_path(:limits, :memory, format_memory_threshold(mem_limit)) if mem_limit
        h.store_path(:limits, :cpu, format_cpu_threshold(cpu_limit)) if cpu_limit

        h.store_path(:requests, :memory, format_memory_threshold(mem_request)) if mem_request
        h.store_path(:requests, :cpu, format_cpu_threshold(cpu_request)) if cpu_request
      end
    end

    def container_image_namespace
      ENV["CONTAINER_IMAGE_NAMESPACE"]
    end

    def container_image_name
      "manageiq-base-worker"
    end

    def container_image_tag
      ENV["CONTAINER_IMAGE_TAG"] || "latest"
    end

    def deployment_prefix
      "#{MiqServer.my_server.compressed_id}-"
    end

    def worker_deployment_name
      @worker_deployment_name ||= begin
        deployment_name = abbreviated_class_name.dup.chomp("Worker").sub("Manager", "").sub(/^Miq/, "")
        deployment_name << "-#{Array(ems_id).map { |id| ApplicationRecord.split_id(id).last }.join("-")}" if respond_to?(:ems_id)
        "#{deployment_prefix}#{deployment_name.underscore.dasherize.tr("/", "-")}"
      end
    end

    private

    def format_memory_threshold(value)
      "#{value / 1.megabyte}Mi"
    end

    def format_cpu_threshold(value)
      "#{((value / 100.0) * 1000).to_i}m"
    end
  end
end
