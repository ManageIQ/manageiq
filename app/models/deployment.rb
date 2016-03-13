module FindVms
  def masters
    where(:classification => 'master')
  end

  def nodes
    where(:classification => 'node')
  end
end

class Deployment < ApplicationRecord
  belongs_to :ext_management_system
  has_many :container_node_deployments, -> { extending FindVms }
  DEPLOYMENT_TYPES = ['OpenShift Origin', 'OpenShift Enterprise', 'Atomic Enterprise'].freeze

  def self.get_supported_types
    DEPLOYMENT_TYPES
  end

  def masters
    container_node_deployments.masters
  end

  def nodes
    container_node_deployments.nodes
  end

  def create_ansible_inventory

  end

end

