class VmMicrosoft < VmInfra

  def archived?
    my_management_system.nil? && self.storage.nil?
  end

  def orphaned?
    my_management_system.nil? && !self.storage.nil?
  end

  def self.calculate_power_state(raw_power_state)
    case raw_power_state
    when "Running"         then "on"
    when "Paused", "Saved" then "suspended"
    when "PowerOff"        then "off"
    else                        super
    end
  end

  private

  def my_management_system
    return self.host if self.host && self.host.ext_management_system.nil?
    self.ext_management_system
  end
end
