class VmVmware < VmInfra
  include_concern 'VmOrTemplate::VmwareShared'

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

  def self.calculate_power_state(raw_power_state)
    case raw_power_state
    when "poweredOn"  then "on"
    when "poweredOff" then "off"
    when "suspended"  then "suspended"
    else                   super
    end
  end
end
