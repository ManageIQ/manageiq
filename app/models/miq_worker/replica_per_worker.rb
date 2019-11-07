class MiqWorker
  module ReplicaPerWorker
    extend ActiveSupport::Concern

    def create_container_objects
      ContainerOrchestrator.new.create_deployment(worker_deployment_name) do |definition|
        configure_worker_deployment(definition)
      end
      scale_deployment
    end

    def delete_container_objects
      ContainerOrchestrator.new.delete_deployment(worker_deployment_name)
    end

    def stop_container
      scale_deployment
    end
  end
end
