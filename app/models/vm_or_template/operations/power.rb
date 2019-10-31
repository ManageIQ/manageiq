module VmOrTemplate::Operations::Power
  def raw_start
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def start
    check_policy_prevent(:request_vm_start, :raw_start)
  end

  def raw_stop
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def stop
    check_policy_prevent(:request_vm_poweroff, :raw_stop)
  end

  # Suspend saves the state of the VM to disk and shuts it down
  def raw_suspend
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def suspend
    check_policy_prevent(:request_vm_suspend, :raw_suspend)
  end

  # All associated data and resources are kept but anything still in memory is not retained.
  def raw_shelve
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def shelve
    check_policy_prevent(:request_vm_shelve, :raw_shelve)
  end

  # Has to be in shelved state first. Data and resource associations are deleted.
  def raw_shelve_offload
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def shelve_offload
    check_policy_prevent(:request_vm_shelve_offload, :raw_shelve_offload)
  end

  # Pause keeps the VM in memory but does not give it CPU cycles.
  # Not supported in VMware, so it is the same as suspend
  def raw_pause
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def pause
    check_policy_prevent(:request_vm_pause, :raw_pause)
  end
end
