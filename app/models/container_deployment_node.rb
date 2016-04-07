class ContainerDeploymentNode < ApplicationRecord
  belongs_to :vm
  belongs_to :container_deployment
  serialize :labels, Hash
  serialize :customizations, Hash
  acts_as_miq_taggable
end
