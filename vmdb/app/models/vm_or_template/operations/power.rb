module VmOrTemplate::Operations::Power
  def raw_start
    run_command_via_parent(:vm_start)
  end

  def start
    raw_start unless policy_prevented?(:request_vm_start)
  end

  def raw_stop
    run_command_via_parent(:vm_stop)
  end

  def stop
    raw_stop unless policy_prevented?(:request_vm_stop)
  end

  # Suspend saves the state of the VM to disk and shuts it down
  def raw_suspend
    run_command_via_parent(:vm_suspend)
  end

  def suspend
    raw_suspend unless policy_prevented?(:request_vm_suspend)
  end

  # Pause keeps the VM in memory but does not give it CPU cycles.
  # Not supported in VMware, so it is the same as suspend
  def raw_pause
    run_command_via_parent(:vm_pause)
  end

  def pause
    raw_pause unless policy_prevented?(:request_vm_pause)
  end
end
