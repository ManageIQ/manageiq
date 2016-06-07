class ApiController
  module ContainerDeployments
    def start_resource_container_deployments(_type, _id, data)
      deployment = ContainerDeployment.new
      deployment.create_deployment(data, @auth_user_obj)
    end

    def collect_data_resource_container_deployments(_type, _id, _data)
      {:data => ContainerDeploymentService.new.all_data}
    end
  end
end
