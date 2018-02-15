class MiqWorker
  module ServiceWorker
    extend ActiveSupport::Concern

    SERVICE_PORT = 3000

    def create_container_objects
      orchestrator = ContainerOrchestrator.new

      orchestrator.create_service(worker_deployment_name, SERVICE_PORT)
      orchestrator.create_deployment_config(worker_deployment_name) do |definition|
        configure_worker_deployment(definition)

        definition[:spec][:serviceName] = worker_deployment_name
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
      orch.delete_deployment_config(worker_deployment_name)
      orch.delete_service(worker_deployment_name)
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

    # Can be overriden by including classes
    def container_port
      SERVICE_PORT
    end

    # Can be overriden by including classes
    def container_image_name
      "manageiq/manageiq-webserver-worker"
    end
  end
end
