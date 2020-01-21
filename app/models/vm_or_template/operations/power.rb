module VmOrTemplate::Operations::Power
  def raw_start
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def start_queue
    run_command_via_queue("raw_start")
  end

  def start
    check_policy_prevent(:request_vm_start, :start_queue)
  end

  def raw_stop
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def stop_queue
    run_command_via_queue("raw_stop")
  end

  def stop
    check_policy_prevent(:request_vm_poweroff, :stop_queue)
  end

  # Suspend saves the state of the VM to disk and shuts it down
  def raw_suspend
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def suspend_queue
    run_command_via_queue("raw_suspend")
  end

  def suspend
    check_policy_prevent(:request_vm_suspend, :suspend_queue)
  end

  # All associated data and resources are kept but anything still in memory is not retained.
  def raw_shelve
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def shelve_queue
    run_command_via_queue("raw_shelve")
  end

  def shelve
    check_policy_prevent(:request_vm_shelve, :shelve_queue)
  end

  # Has to be in shelved state first. Data and resource associations are deleted.
  def raw_shelve_offload
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def shelve_offload_queue
    run_command_via_queue("raw_shelve_offload")
  end

  def shelve_offload
    check_policy_prevent(:request_vm_shelve_offload, :shelve_offload_queue)
  end

  # Pause keeps the VM in memory but does not give it CPU cycles.
  # Not supported in VMware, so it is the same as suspend
  def raw_pause
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def pause_queue
    run_command_via_queue("raw_pause")
  end

  def pause
    check_policy_prevent(:request_vm_pause, :pause_queue)
  end
end
