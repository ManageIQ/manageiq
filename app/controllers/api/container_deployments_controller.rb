module Api
  class ContainerDeploymentsController < BaseController
    def create_resource(_type, _id, data)
      deployment = ContainerDeployment.new
      deployment.create_deployment(data, @auth_user_obj)
    end

    def options
      render_options(:container_deployments, ContainerDeploymentService.new.all_data)
    end
  end
end
