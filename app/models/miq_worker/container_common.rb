require 'kubeclient'

class MiqWorker
  module ContainerCommon
    extend ActiveSupport::Concern

    def configure_worker_deployment(definition, replicas = 0)
      definition[:spec][:replicas] = replicas
      definition[:spec][:template][:spec][:terminationGracePeriodSeconds] = self.class.worker_settings[:stopping_timeout].seconds

      container = definition[:spec][:template][:spec][:containers].first
      container[:image] = "#{container_image_name}:#{container_image_tag}"
      container[:env] << {:name => "WORKER_CLASS_NAME", :value => self.class.name}
    end

    def scale_deployment
      ContainerOrchestrator.new.scale(worker_deployment_name, self.class.workers_configured_count)
      delete_container_objects if self.class.workers_configured_count.zero?
    end

    def container_image_name
      "manageiq/manageiq-base-worker"
    end

    def container_image_tag
      "latest"
    end

    def worker_deployment_name
      @worker_deployment_name ||= begin
        deployment_name = abbreviated_class_name.dup.chomp("Worker").sub("Manager", "").sub(/^Miq/, "")
        deployment_name << "-#{Array(ems_id).map { |id| ApplicationRecord.split_id(id).last }.join("-")}" if respond_to?(:ems_id)
        deployment_name.underscore.dasherize.tr("/", "-")
      end
    end
  end
end
