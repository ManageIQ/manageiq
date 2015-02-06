class ContainerDefinition < ActiveRecord::Base
  # :name, :image, :image_pull_policy, :memory, :cpu
  belongs_to :container_group
  has_many :container_port_configs
end
