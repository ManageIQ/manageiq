module ManageIQ::Providers::Google::CloudManager::Vm::Operations::Power
  def validate_suspend
    validate_unsupported("Suspend Operation")
  end

  def validate_pause
    validate_unsupported("Pause Operation")
  end

  def raw_start
    with_provider_object(&:start)
    self.update_attributes!(:raw_power_state => "starting")
  end

  def raw_stop
    with_provider_object(&:stop)
    self.update_attributes!(:raw_power_state => "stopping")
  end
end
