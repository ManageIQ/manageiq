class ContainerDefinition < ActiveRecord::Base
  # :name, :image, :image_pull_policy, :memory, :cpu
  belongs_to :container_group
  has_many :container_port_configs, :dependent => :destroy
  has_many :container_env_vars,     :dependent => :destroy
  has_one :container,               :dependent => :destroy
end
