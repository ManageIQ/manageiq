class ManageIQ::Providers::Microsoft::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern 'ManageIQ::Providers::Microsoft::InfraManager::VmOrTemplateShared'

  supports_not :migrate, :reason => _("Migrate operation is not supported.")
  supports     :reset

  POWER_STATES = {
    "Running"  => "on",
    "Paused"   => "suspended",
    "Saved"    => "suspended",
    "PowerOff" => "off",
  }.freeze

  def self.calculate_power_state(raw_power_state)
    POWER_STATES[raw_power_state] || super
  end

  def proxies4job(_job = nil)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this VM'
    }
  end

  def has_active_proxy?
    true
  end

  def has_proxy?
    true
  end

  def validate_publish
    validate_unsupported("Publish VM")
  end
end
