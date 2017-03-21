module Api
  class ContainerDeploymentsController < BaseController
    def create_resource(_type, _id, data)
      deployment = ContainerDeployment.new
      deployment.create_deployment(data, User.current_user)
    end

    def options
      render_options(:container_deployments, :deployment_types => ContainerDeployment::DEPLOYMENT_TYPES)
    end
  end
end
