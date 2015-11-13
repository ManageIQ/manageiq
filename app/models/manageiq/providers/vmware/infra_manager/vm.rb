class ManageIQ::Providers::Vmware::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'ManageIQ::Providers::Vmware::InfraManager::VmOrTemplateShared'

  include_concern 'Operations'
  include_concern 'RemoteConsole'

  def add_miq_alarm
    raise "VM has no EMS, unable to add alarm" unless ext_management_system
    ext_management_system.vm_add_miq_alarm(self)
  end
  alias_method :addMiqAlarm, :add_miq_alarm

  def scan_on_registered_host_only?
    state == "on"
  end

  # Show certain non-generic charts
  def cpu_ready_available?
    true
  end

  def cloneable?
    true
  end

  def supports_snapshots?
    true
  end

  def validate_migrate
    validate_supported
  end

  #
  # Show Reconfigure VM task
  def reconfigurable?
    true
  end

  def max_total_vcpus
    [host.hardware.cpu_total_cores, max_total_vcpus_by_version].min
  end

  def max_total_vcpus_by_version
    case hardware.virtual_hw_version
    when "04"       then 4
    when "07"       then 8
    when "08"       then 32
    when "09", "10" then 64
    end
  end

  def max_cpu_cores_per_socket(_total_vcpus = nil)
    case hardware.virtual_hw_version
    when "04"       then 1
    when "07"       then [1, 2, 4, 8].include?(max_total_vcpus) ? max_total_vcpus : 1
    else            max_total_vcpus
    end
  end

  def max_vcpus
    max_total_vcpus
  end

  def max_memory_mb
    case hardware.virtual_hw_version
    when "04"             then   64.gigabyte / 1.megabyte
    when "07"             then  255.gigabyte / 1.megabyte
    when "08", "09", "10" then 1011.gigabyte / 1.megabyte
    end
  end
end
