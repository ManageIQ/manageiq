module ManageIQ::Providers::Amazon::CloudManager::Vm::Operations::Power
  def validate_suspend
    validate_unsupported("Suspend Operation")
  end

  def validate_pause
    validate_unsupported("Pause Operation")
  end

  def raw_start
    with_provider_object(&:start)
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "powering_up")
  end

  def raw_stop
    with_provider_object(&:stop)
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "shutting_down")
  end
end
