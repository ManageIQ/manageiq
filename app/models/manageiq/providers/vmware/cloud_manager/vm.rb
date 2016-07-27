class ManageIQ::Providers::Vmware::CloudManager::Vm < ManageIQ::Providers::CloudManager::Vm
  include_concern 'Operations'

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.vms.get_single_vm(uid_ems)
  end

  POWER_STATES = {
    "creating"  => "powering_up",
    "off"       => "off",
    "on"        => "on",
    "unknown"   => "terminated",
    "suspended" => "suspended"
  }.freeze

  def self.calculate_power_state(raw_power_state)
    # https://github.com/xlab-si/fog-vcloud-director/blob/master/lib/fog/vcloud_director/parsers/compute/vm.rb#L70
    POWER_STATES[raw_power_state.to_s] || "terminated"
  end
end
