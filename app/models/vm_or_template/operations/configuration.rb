module VmOrTemplate::Operations::Configuration
  def raw_set_memory(_mb)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def set_memory(mb)
    raise _("VM has no EMS, unable to reconfigure memory") unless ext_management_system

    raw_set_memory(mb)
  end

  def raw_set_number_of_cpus(_num)
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

  def raw_add_disk(_disk_name, _disk_size_mb, _options = {})
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def add_disk(disk_name, disk_size_mb, options = {})
    raise _("VM has no EMS, unable to add disk") unless ext_management_system

    raw_add_disk(disk_name, disk_size_mb, options)
  end

  def raw_remove_disk(_disk_name, _options = {})
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def remove_disk(disk_name, options = {})
    raise _("VM has no EMS, unable to remove disk") unless ext_management_system

    raw_remove_disk(disk_name, options)
  end

  def resize_disk(disk_name, disk_size_mb, options = {})
    raise _("VM has no EMS, unable to resize disk") unless ext_management_system

    raw_resize_disk(disk_name, disk_size_mb, options)
  end

  def raw_resize_disk(_disk_name, _disk_size_mb, _options = {})
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def raw_attach_volume(_volume_id, _device = nil)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def attach_volume(volume_id, device = nil)
    raise _("VM has no EMS, unable to attach volume") unless ext_management_system

    raw_attach_volume(volume_id, device)
  end

  def raw_detach_volume(_volume_id)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def detach_volume(volume_id, _device = nil)
    raise _("VM has no EMS, unable to detach volume") unless ext_management_system

    raw_detach_volume(volume_id)
  end

  def raw_clone_volume(_options = {})
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def clone_volume(options = {})
    raise _("VM has no EMS, unable to clone volume") unless ext_management_system

    raw_clone_volume(options)
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
