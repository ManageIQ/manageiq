module ManageIQ::Providers::Openstack::CloudManager::Vm::Operations::Guest
  def validate_reboot_guest
    return {:available => supports_vm_control_powered_on?, :message => unsupported_reason(:vm_control_powered_on)}
  end

  def validate_reset
    return {:available => supports_vm_control_powered_on?, :message => unsupported_reason(:vm_control_powered_on)}
  end

  def raw_reboot_guest
    with_provider_object(&:reboot)
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "REBOOT")
  end

  def raw_reset
    with_provider_object { |instance| instance.reboot("HARD") }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "HARD_REBOOT")
  end
end
