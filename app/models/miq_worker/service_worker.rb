class MiqWorker
  module ServiceWorker
    extend ActiveSupport::Concern

    SERVICE_PORT = 3000

    def create_container_objects
      orchestrator = ContainerOrchestrator.new

      orchestrator.create_deployment(worker_deployment_name) do |definition|
        configure_worker_deployment(definition)

        definition[:spec][:template][:metadata][:labels].merge!(service_label)

        container = definition[:spec][:template][:spec][:containers].first
        container[:ports] = [{:containerPort => SERVICE_PORT}]
        container[:env] << {:name => "PORT", :value => container_port.to_s}
        container[:env] << {:name => "BINDING_ADDRESS", :value => "0.0.0.0"}
        add_readiness_probe(container)
      end

      scale_deployment
    end

    def delete_container_objects
      orch = ContainerOrchestrator.new
      orch.delete_deployment(worker_deployment_name)
    end

    def stop_container
      scale_deployment
    end

    def add_readiness_probe(container_definition)
      container_definition[:readinessProbe] = {
        :tcpSocket           => {:port => SERVICE_PORT},
        :initialDelaySeconds => 60,
        :timeoutSeconds      => 3
      }
    end

    def service_label
      {:service => worker_deployment_name.delete_prefix(deployment_prefix)}
    end

    # Can be overriden by including classes
    def container_port
      SERVICE_PORT
    end

    # Can be overriden by including classes
    def container_image_name
      "manageiq-webserver-worker"
    end

    def container_image
      ENV["WEBSERVER_WORKER_IMAGE"] || default_image
    end
  end
end
