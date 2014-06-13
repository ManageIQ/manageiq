module Vm::Operations::Guest
  def validate_shutdown_guest
    validate_unsupported("Shutdown Guest Operation")
  end

  def validate_standby_guest
    validate_unsupported("Standby Guest Operation")
  end

  def validate_reboot_guest
    validate_unsupported("Reboot Guest Operation")
  end

  def validate_reset
    validate_unsupported("Reset Guest Operation")
  end

  def raw_shutdown_guest
    raise "VM has no #{ui_lookup(:table=>"ext_management_systems")}, unable to shutdown guest OS" unless self.has_active_ems?
    run_command_via_parent(:vm_shutdown_guest)
  end

  def shutdown_guest
    raw_shutdown_guest unless policy_prevented?(:request_vm_shutdown_guest)
  end

  def raw_standby_guest
    raise "VM has no #{ui_lookup(:table=>"ext_management_systems")}, unable to standby guest OS" unless self.has_active_ems?
    run_command_via_parent(:vm_standby_guest)
  end

  def standby_guest
    raw_standby_guest unless policy_prevented?(:request_vm_standby_guest)
  end

  def raw_reboot_guest
    raise "VM has no #{ui_lookup(:table=>"ext_management_systems")}, unable to reboot guest OS" unless self.has_active_ems?
    run_command_via_parent(:vm_reboot_guest)
  end

  def reboot_guest
    raw_reboot_guest unless policy_prevented?(:request_vm_reboot_guest)
  end

  def raw_reset
    raise "VM has no #{ui_lookup(:table=>"ext_management_systems")}, unable to reset VM" unless self.has_active_ems?
    run_command_via_parent(:vm_reset)
  end

  def reset
    raw_reset unless policy_prevented?(:request_vm_reset)
  end
end
