module ManageIQ::Providers::Vmware::CloudManager::Vm::Operations::Power
  def validate_pause
    validate_unsupported("Pause operation")
  end

  def raw_start
    with_provider_object(&:power_on)
    update_attributes!(:raw_power_state => "on")
  end

  def raw_stop
    with_provider_object(&:power_off)
    update_attributes!(:raw_power_state => "off")
  end

  def raw_suspend
    with_provider_object(&:suspend)
    update_attributes!(:raw_power_state => "suspended")
  end

  def raw_restart
    with_provider_object(&:reset)
    update_attributes!(:raw_power_state => "on")
  end
end
