module FindVms
  def masters
    where(:classification => 'master')
  end

  def nodes
    where(:classification => 'node')
  end
end

class Deployment < ApplicationRecord
  has_many :vms, -> { extending FindVms }
  has_many :unmanaged_vms, -> { extending FindVms }
  DEPLOYMENT_TYPES = ['OpenShift Origin', 'OpenShift Enterprise', 'Atomic Enterprise'].freeze

  def self.get_supported_types
    DEPLOYMENT_TYPES
  end

  def associated_vms
    if deployment_type == "unmanaged"
      unmanaged_vms
    else
      vms
    end
  end

  def masters
    associated_vms.masters
  end

  def nodes
    associated_vms.nodes
  end

end

