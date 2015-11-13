class ManageIQ::Providers::Redhat::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'Operations'
  include_concern 'RemoteConsole'
  include_concern 'ManageIQ::Providers::Redhat::InfraManager::VmOrTemplateShared'

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

  def cloneable?
    true
  end

  def self.calculate_power_state(raw_power_state)
    case raw_power_state
    when 'up'        then 'on'
    when 'down'      then 'off'
    when 'suspended' then 'suspended'
    else                  super
    end
  end

  def validate_migrate
    validate_unsupported("Migrate")
  end

  # Show Reconfigure VM task
  def reconfigurable?
    true
  end

  def max_total_vcpus
    # the default value of MaxNumOfVmCpusTotal for RHEV 3.1 - 3.4
    160
  end

  def max_cpu_cores_per_socket
    # the default value of MaxNumOfCpuPerSocket for RHEV 3.1 - 3.4
    16
  end

  def max_vcpus
    # the default value of MaxNumofVmSockets for RHEV 3.1 - 3.4
    16
  end

  def max_memory_mb
    2.terabyte / 1.megabyte
  end
end
