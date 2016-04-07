class ContainerDeploymentNode < ApplicationRecord
  belongs_to :vm
  belongs_to :container_deployment
  serialize :labels, Hash
  acts_as_miq_taggable
end
