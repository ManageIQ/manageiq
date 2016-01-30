class ManageIQ::Providers::Microsoft::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'ManageIQ::Providers::Microsoft::InfraManager::VmOrTemplateShared'

  def self.calculate_power_state(raw_power_state)
    case raw_power_state
    when "Running"         then "on"
    when "Paused", "Saved" then "suspended"
    when "PowerOff"        then "off"
    else                        super
    end
  end

  def validate_migrate
    validate_unsupported("Migrate")
  end
end
