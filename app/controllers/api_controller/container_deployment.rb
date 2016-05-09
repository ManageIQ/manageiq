class ApiController
  module ContainerDeployment
    def start_resource_container_deployments(type, _id, data)
      byebug
      deployment = ContainerDeployment.new
      deployment.create_deployment(data)
    end
  end
end
