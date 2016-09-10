module ManageIQ::Providers::Vmware::InfraManager::Vm::Operations::Guest
  def validate_shutdown_guest
    msg = validate_vm_control
    return {:available => msg[0], :message => msg[1]} unless msg.nil?
    return {:available => true,   :message => ''}     if tools_status && tools_status == 'toolsNotInstalled'
    return {:available => true,   :message => nil}    if current_state == 'on'
    {:available => false,  :message => 'The VM is not powered on'}
  end

  def validate_standby_guest
    {:available => supports_vm_control_powered_on?, :message => unsupported_reason(:vm_control_powered_on)}
  end

  def validate_reboot_guest
    {:available => supports_vm_control_powered_on?, :message => unsupported_reason(:vm_control_powered_on)}
  end

  def validate_reset
    {:available => supports_vm_control_powered_on?, :message => unsupported_reason(:vm_control_powered_on)}
  end
end
