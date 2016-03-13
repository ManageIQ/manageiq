class ContainerNodeDeployment < ApplicationRecord
  has_one :vm
  belongs_to :deployment
end
