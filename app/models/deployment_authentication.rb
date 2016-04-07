class DeploymentAuthentication < ApplicationRecord
  belongs_to :container_deployment
  serialize :htpassd_users
end
