class VmMicrosoft < VmInfra
  def self.calculate_power_state(raw_power_state)
    case raw_power_state
    when "Running"         then "on"
    when "Paused", "Saved" then "suspended"
    when "PowerOff"        then "off"
    else                        super
    end
  end
end
