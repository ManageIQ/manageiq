class ManageIQ::Providers::Vmware::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'ManageIQ::Providers::Vmware::InfraManager::VmOrTemplateShared'

  include_concern 'Operations'
  include_concern 'RemoteConsole'

  def add_miq_alarm
    raise "VM has no EMS, unable to add alarm" unless self.ext_management_system
    self.ext_management_system.vm_add_miq_alarm(self)
  end
  alias addMiqAlarm add_miq_alarm

  def scan_on_registered_host_only?
    self.state == "on"
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
end
