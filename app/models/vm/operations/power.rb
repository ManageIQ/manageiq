module Vm::Operations::Power
  def validate_start
    return {:available => supports_vm_control_not_powered_on?, :message => unsupported_reason(:vm_control_not_powered_on)}
  end

  def validate_stop
    return {:available => supports_vm_control_powered_on?, :message => unsupported_reason(:vm_control_powered_on)}
  end

  def validate_suspend
    return {:available => supports_vm_control_powered_on?, :message => unsupported_reason(:vm_control_powered_on)}
  end

  def validate_pause
    return {:available => supports_vm_control_powered_on?, :message => unsupported_reason(:vm_control_powered_on)}
  end

  def validate_shelve
    validate_unsupported("Shelve Operation")
  end

  def validate_shelve_offload
    validate_unsupported("Shelve Offload Operation")
  end
end
