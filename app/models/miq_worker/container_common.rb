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
      mem_threshold = self.class.worker_settings[:memory_threshold]
      cpu_threshold = self.class.worker_settings[:cpu_threshold_percent]

      return {} if !Settings.server.worker_monitor.enforce_resource_constraints || (mem_threshold.nil? && cpu_threshold.nil?)

      {:limits => {}}.tap do |h|
        h[:limits][:memory] = "#{mem_threshold / 1.megabyte}Mi" if mem_threshold
        if cpu_threshold
          millicores = ((cpu_threshold / 100.0) * 1000).to_i
          h[:limits][:cpu] = "#{millicores}m"
        end
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
  end
end
