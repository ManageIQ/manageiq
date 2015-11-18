class ManageIQ::Providers::Google::CloudManager::Vm < ManageIQ::Providers::CloudManager::Vm
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.instances[ems_ref]
  end

  #
  # Relationship methods
  #

  def disconnect_inv
    super

    # Mark all instances no longer found as terminated
    power_state == "off"
    save
  end

  def disconnected
    false
  end

  def disconnected?
    false
  end

  def self.calculate_power_state(raw_power_state)
    case raw_power_state.downcase
    when "running"
      "on"
    when "terminated"
      "off"
    else
      "unknown"
    end
  end
end
