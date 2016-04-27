module ManageIQ::Providers::Softlayer::CloudManager::Vm::Operations::Guest
  def validate_reboot_guest
    validate_vm_control_powered_on
  end

  def raw_reboot_guest
    with_provider_object(&:reboot)
    update_attributes!(:raw_power_state => "reboot")
  end
end
