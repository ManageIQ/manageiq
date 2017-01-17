module VmOrTemplate::Operations::Configuration
  def raw_set_memory(mb)
    raise _("VM has no EMS, unable to reconfigure memory") unless ext_management_system
    run_command_via_parent(:vm_set_memory, :value => mb)
  end

  def set_memory(mb)
    raw_set_memory(mb)
  end

  def raw_set_number_of_cpus(num)
    raise _("VM has no EMS, unable to reconfigure CPUs") unless ext_management_system
    run_command_via_parent(:vm_set_num_cpus, :value => num)
  end

  def set_number_of_cpus(num)
    raw_set_number_of_cpus(num)
  end

  def raw_connect_all_devices
    raise _("VM has no EMS, unable to connect all devices") unless ext_management_system
    run_command_via_parent(:vm_connect_all)
  end

  def connect_all_devices
    raw_connect_all_devices
  end

  def raw_disconnect_all_devices
    raise _("VM has no EMS, unable to disconnect all devices") unless ext_management_system
    run_command_via_parent(:vm_disconnect_all)
  end

  def disconnect_all_devices
    raw_disconnect_all_devices
  end

  def raw_connect_cdroms
    raise _("VM has no EMS, unable to connect CD-ROM devices") unless ext_management_system
    run_command_via_parent(:vm_connect_cdrom)
  end

  def connect_cdroms
    raw_connect_cdroms
  end

  def raw_disconnect_cdroms
    raise _("VM has no EMS, unable to disconnect CD-ROM devices") unless ext_management_system
    run_command_via_parent(:vm_disconnect_cdrom)
  end

  def disconnect_cdroms
    raw_disconnect_cdroms
  end

  def raw_connect_floppies
    raise _("VM has no EMS, unable to connect Floppy devices") unless ext_management_system
    run_command_via_parent(:vm_connect_floppy)
  end

  def connect_floppies
    raw_connect_floppies
  end

  def raw_disconnect_floppies
    raise _("VM has no EMS, unable to disconnect Floppy devices") unless ext_management_system
    run_command_via_parent(:vm_disconnect_floppy)
  end

  def disconnect_floppies
    raw_disconnect_floppies
  end

  def raw_add_disk(disk_name, disk_size_mb, options = {})
    raise _("VM has no EMS, unable to add disk") unless ext_management_system
    if options[:datastore]
      datastore = Storage.find_by(:name => options[:datastore])
      raise _("Data Store does not exist, unable to add disk") unless datastore
    end

    run_command_via_parent(:vm_add_disk, :diskName => disk_name, :diskSize => disk_size_mb,
        :thinProvisioned => options[:thin_provisioned], :dependent => options[:dependent],
        :persistent => options[:persistent], :bootable => options[:bootable], :datastore => datastore,
        :interface => options[:interface])
  end

  def add_disk(disk_name, disk_size_mb, options = {})
    raw_add_disk(disk_name, disk_size_mb, options)
  end

  def raw_attach_volume(volume_id, device = nil)
    raise _("VM has no EMS, unable to attach volume") unless ext_management_system
    run_command_via_parent(:vm_attach_volume, :volume_id, :device)
  end

  def attach_volume(volume_id, device = nil)
    raw_attach_volume(volume_id, device)
  end

  def raw_detach_volume(volume_id)
    raise _("VM has no EMS, unable to detach volume") unless ext_management_system
    run_command_via_parent(:vm_detach_volume, :volume_id)
  end

  def detach_volume(volume_id, device = nil)
    raw_detach_volume(volume_id)
  end

  def spec_reconfigure(spec)
    raise _("VM has no EMS, unable to apply reconfigure spec") unless ext_management_system
    run_command_via_parent(:vm_reconfigure, :spec => spec)
  end
end
