class VmOpenstack < VmCloud
  include_concern 'Operations'

  belongs_to :cloud_tenant

  def provider_object(connection = nil)
    connection ||= self.ext_management_system.connect
    connection.servers.get(self.ems_ref)
  end

  def self.calculate_power_state(raw_power_state)
    case raw_power_state
    when "RUNNING"                                    then "on"
    when "BLOCKED", "PAUSED", "SUSPENDED", "BUILDING" then "suspended"
    when "SHUTDOWN", "SHUTOFF", "CRASHED", "FAILED"   then "off"
    else                                                   super
    end
  end
end
