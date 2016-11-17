class ManageIQ::Providers::Vmware::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'ManageIQ::Providers::Vmware::InfraManager::VmOrTemplateShared'

  include_concern 'Operations'
  include_concern 'RemoteConsole'
  include_concern 'Reconfigure'

  supports :reconfigure_disks

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

  supports :quick_stats
end
