class ManageIQ::Providers::Redhat::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'Operations'
  include_concern 'RemoteConsole'
  include_concern 'Reconfigure'
  include_concern 'ManageIQ::Providers::Redhat::InfraManager::VmOrTemplateShared'

  supports_not :migrate, :reason => _("Migrate operation is not supported.")

  POWER_STATES = {
    'up'        => 'on',
    'down'      => 'off',
    'suspended' => 'suspended',
  }.freeze

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.get_resource_by_ems_ref(ems_ref)
  end

  def scan_via_ems?
    true
  end

  def parent_cluster
    rp = parent_resource_pool
    rp && rp.detect_ancestor(:of_type => "EmsCluster").first
  end
  alias_method :owning_cluster, :parent_cluster
  alias_method :ems_cluster, :parent_cluster

  #
  # UI Button Validation Methods
  #

  def has_required_host?
    true
  end

  def self.calculate_power_state(raw_power_state)
    POWER_STATES[raw_power_state] || super
  end

  def validate_publish
    validate_unsupported("Publish VM")
  end
end
