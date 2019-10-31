module VmOrTemplate::Operations::Configuration
  def raw_set_memory(mb)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def set_memory(mb)
    raise _("VM has no EMS, unable to reconfigure memory") unless ext_management_system

    raw_set_memory(mb)
  end

  def raw_set_number_of_cpus(num)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def set_number_of_cpus(num)
    raise _("VM has no EMS, unable to reconfigure CPUs") unless ext_management_system

    raw_set_number_of_cpus(num)
  end

  def raw_connect_all_devices
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def connect_all_devices
    raise _("VM has no EMS, unable to connect all devices") unless ext_management_system

    raw_connect_all_devices
  end

  def raw_disconnect_all_devices
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def disconnect_all_devices
    raise _("VM has no EMS, unable to disconnect all devices") unless ext_management_system

    raw_disconnect_all_devices
  end

  def raw_connect_cdroms
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def connect_cdroms
    raise _("VM has no EMS, unable to connect CD-ROM devices") unless ext_management_system

    raw_connect_cdroms
  end

  def raw_disconnect_cdroms
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def disconnect_cdroms
    raise _("VM has no EMS, unable to disconnect CD-ROM devices") unless ext_management_system

    raw_disconnect_cdroms
  end

  def raw_connect_floppies
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def connect_floppies
    raise _("VM has no EMS, unable to connect Floppy devices") unless ext_management_system

    raw_connect_floppies
  end

  def raw_disconnect_floppies
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def disconnect_floppies
    raise _("VM has no EMS, unable to disconnect Floppy devices") unless ext_management_system

    raw_disconnect_floppies
  end

  def raw_add_disk(disk_name, disk_size_mb, options = {})
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def add_disk(disk_name, disk_size_mb, options = {})
    raise _("VM has no EMS, unable to add disk") unless ext_management_system

    raw_add_disk(disk_name, disk_size_mb, options)
  end

  def raw_remove_disk(disk_name, options = {})
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def remove_disk(disk_name, options = {})
    raise _("VM has no EMS, unable to remove disk") unless ext_management_system

    raw_remove_disk(disk_name, options)
  end

  def raw_attach_volume(volume_id, device = nil)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def attach_volume(volume_id, device = nil)
    raise _("VM has no EMS, unable to attach volume") unless ext_management_system

    raw_attach_volume(volume_id, device)
  end

  def raw_detach_volume(volume_id)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def detach_volume(volume_id, device = nil)
    raise _("VM has no EMS, unable to detach volume") unless ext_management_system

    raw_detach_volume(volume_id)
  end

  def raw_reconfigure
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def reconfigure(spec)
    raise _("VM has no EMS, unable to apply reconfigure spec") unless ext_management_system

    raw_reconfigure(spec)
  end
  alias spec_reconfigure reconfigure
end
