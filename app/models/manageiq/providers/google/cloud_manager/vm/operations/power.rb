module ManageIQ::Providers::Google::CloudManager::Vm::Operations::Power
  def validate_suspend
    validate_unsupported(_("Suspend Operation"))
  end

  def validate_pause
    validate_unsupported(_("Pause Operation"))
  end

  def raw_suspend
    validate_unsupported(_("Suspend Operation"))
  end

  def raw_pause
    validate_unsupported(_("Pause Operation"))
  end

  def raw_shelve
    validate_unsupported(_("Shelve Operation"))
  end

  def raw_shelve_offload
    validate_unsupported(_("Shelve Offload Operation"))
  end

  def raw_start
    with_provider_object(&:start)
    # it's a better user experience if we update the state here, but should we
    # be making a service call instead?
    update_attributes!(:raw_power_state => "PROVISIONING")
  end

  def raw_stop
    with_provider_object(&:stop)
    # it's a better user experience if we update the state here, but should we
    # be making a service call instead?
    update_attributes!(:raw_power_state => "STOPPING")
  end
end
