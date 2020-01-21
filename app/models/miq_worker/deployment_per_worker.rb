class MiqWorker
  module DeploymentPerWorker
    extend ActiveSupport::Concern

    def create_container_objects
      ContainerOrchestrator.new.create_deployment(worker_deployment_name) do |definition|
        configure_worker_deployment(definition, 1)
        definition[:spec][:template][:spec][:containers].first[:env] << {:name => "EMS_IDS", :value => Array.wrap(self.class.ems_id_from_queue_name(queue_name)).join(",")}
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
