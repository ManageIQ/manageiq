class ManageIQ::Providers::Redhat::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'Operations'
  include_concern 'RemoteConsole'

  def provider_object(connection = nil)
    connection ||= self.ext_management_system.connect
    connection.get_resource_by_ems_ref(self.ems_ref)
  end

  def scan_via_ems?
    true
  end

  def parent_cluster
    rp = self.parent_resource_pool
    rp && rp.detect_ancestor(:of_type => "EmsCluster").first
  end
  alias owning_cluster parent_cluster
  alias ems_cluster parent_cluster

  #
  # UI Button Validation Methods
  #

  def has_required_host?
    true
  end

  def cloneable?
    true
  end

  def self.calculate_power_state(raw_power_state)
    case raw_power_state
    when 'up'   then 'on'
    when 'down' then 'off'
    else             super
    end
  end

  def validate_migrate
    validate_unsupported("Migrate")
  end
end
