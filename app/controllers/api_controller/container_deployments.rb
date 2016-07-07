class ApiController
  module ContainerDeployments
    def show_container_deployments
      validate_api_action
      if @req.c_id == "container_deployment_data"
        render_resource :container_deployments, :data => ContainerDeploymentService.new.all_data
      else
        show_generic
      end
    end

    def create_resource_container_deployments(_type, _id, data)
      deployment = ContainerDeployment.new
      deployment.create_deployment(data, @auth_user_obj)
    end
  end
end
