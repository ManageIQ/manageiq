class ManageIQ::Providers::Oracle::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'ManageIQ::Providers::Oracle::InfraManager::VmOrTemplateShared'

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
    when Fog::Oracle::VmRunState::STARTING then "off"
    when Fog::Oracle::VmRunState::RUNNING then "on"
    when Fog::Oracle::VmRunState::STOPPING then "off"
    when Fog::Oracle::VmRunState::STOPPED then "off"
    when Fog::Oracle::VmRunState::SUSPENDED then "suspended"
    else                  super
    end
  end

  def validate_migrate
    validate_unsupported("Migrate")
  end

  def validate_smartstate_analysis
    validate_supported_check("Smartstate Analysis")
  end

  # Show Reconfigure VM task
  def reconfigurable?
    true
  end

  def max_total_vcpus
    160
  end

  def max_cpu_cores_per_socket
    16
  end

  def max_vcpus
    16
  end

  def max_memory_mb
    2.terabyte / 1.megabyte
  end
end
