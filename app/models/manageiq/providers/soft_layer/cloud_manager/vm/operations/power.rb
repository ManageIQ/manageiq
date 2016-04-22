module ManageIQ::Providers::SoftLayer::CloudManager::Vm::Operations::Power
  def validate_suspend
    validate_unsupported(_("Suspend Operation"))
  end

  def validate_pause
    validate_unsupported(_("Pause Operation"))
  end

  def raw_start
    with_provider_object(&:start)
    update_attributes!(:raw_power_state => "Starting")
  end

  def raw_stop
    with_provider_object(&:stop)
    update_attributes!(:raw_power_state => "Stopping")
  end

  def raw_restart
    with_provider_object(&:reboot)
    update_attributes!(:raw_power_state => "Rebooting")
  end
end
