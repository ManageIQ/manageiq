module ManageIQ::Providers::Google::CloudManager::Vm::Operations::Guest
  def validate_reboot_guest
    {:available => supports_vm_control_powered_on?, :message => unsupported_reason(:vm_control_powered_on)}
  end

  def raw_reboot_guest
    with_provider_object(&:reboot)
    self.update_attributes!(:raw_power_state => "reboot") # show state as suspended
  end
end
