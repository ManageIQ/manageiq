module ManageIQ::Providers::Google::CloudManager::Vm::Operations::Guest
  def validate_reboot_guest
    validate_vm_control_powered_on
  end

  def raw_reboot_guest
    with_provider_object(&:reboot)
    # Other providers update the power state, but we don't have a "reboot" state
  end
end
