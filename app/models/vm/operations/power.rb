module Vm::Operations::Power
  def validate_start
    validate_vm_control_not_powered_on
  end

  def validate_stop
    validate_vm_control_powered_on
  end

  def validate_suspend
    validate_vm_control_powered_on
  end

  def validate_pause
    validate_vm_control_powered_on
  end
end
