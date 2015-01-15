module VmOpenstack::Operations::Guest
  def validate_reboot_guest
    validate_vm_control_powered_on
  end

  def validate_reset
    validate_vm_control_powered_on
  end

  def raw_reboot_guest
    with_provider_object(&:reboot)
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "SUSPENDED")
  end

  def raw_reset
    with_provider_object { |instance| instance.reboot("HARD") }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "SUSPENDED")
  end
end
