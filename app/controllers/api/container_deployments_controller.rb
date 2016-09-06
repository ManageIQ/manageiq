module Api
  class ContainerDeploymentsController < BaseController
    def show
      if @req.c_id == "container_deployment_data"
        render_resource :container_deployments, :data => ContainerDeploymentService.new.all_data
      else
        super
      end
    end

    def create_resource_container_deployments(_type, _id, data)
      deployment = ContainerDeployment.new
      deployment.create_deployment(data, @auth_user_obj)
    end
  end
end
