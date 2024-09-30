class MiqWorker
  module DeploymentPerWorker
    extend ActiveSupport::Concern

    def create_container_objects
      ContainerOrchestrator.new.create_deployment(worker_deployment_name) do |definition|
        configure_worker_deployment(definition, 1)
      end
    end

    def delete_container_objects
      ContainerOrchestrator.new.delete_deployment(worker_deployment_name)
    end

    def stop_container
      delete_container_objects
    end
  end
end
