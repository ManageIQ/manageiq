module ManageIQ::Providers::Azure::CloudManager::Vm::Operations::Power
  def validate_suspend
    validate_unsupported(_("Suspend Operation"))
  end

  def validate_pause
    validate_unsupported(_("Pause Operation"))
  end

  def raw_start
    provider_service.start(name, resource_group)
    update_attributes!(:raw_power_state => "VM starting")
  end

  def raw_stop
    provider_service.stop(name, resource_group)
    update_attributes!(:raw_power_state => "VM stopping")
  end

  def raw_restart
    provider_service.restart(name, resource_group)
    update_attributes!(:raw_power_state => "VM starting")
  end
end
