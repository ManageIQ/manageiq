module VmOrTemplate::Operations::Configuration
  def raw_set_memory(mb)
    raise "VM has no EMS, unable to reconfigure memory" unless self.ext_management_system
    run_command_via_parent(:vm_set_memory, :value => mb)
  end

  def set_memory(mb)
    raw_set_memory(mb)
  end

  def raw_set_number_of_cpus(num)
    raise "VM has no EMS, unable to reconfigure CPUs" unless self.ext_management_system
    run_command_via_parent(:vm_set_num_cpus, :value => num)
  end

  def set_number_of_cpus(num)
    raw_set_number_of_cpus(num)
  end

  def raw_connect_all_devices
    raise "VM has no EMS, unable to connect all devices" unless self.ext_management_system
    run_command_via_parent(:vm_connect_all)
  end

  def connect_all_devices
    raw_connect_all_devices
  end

  def raw_disconnect_all_devices
    raise "VM has no EMS, unable to disconnect all devices" unless self.ext_management_system
    run_command_via_parent(:vm_disconnect_all)
  end

  def disconnect_all_devices
    raw_disconnect_all_devices
  end

  def raw_connect_cdroms
    raise "VM has no EMS, unable to connect CD-ROM devices" unless self.ext_management_system
    run_command_via_parent(:vm_connect_cdrom)
  end

  def connect_cdroms
    raw_connect_cdroms
  end

  def raw_disconnect_cdroms
    raise "VM has no EMS, unable to disconnect CD-ROM devices" unless self.ext_management_system
    run_command_via_parent(:vm_disconnect_cdrom)
  end

  def disconnect_cdroms
    raw_disconnect_cdroms
  end

  def raw_connect_floppies
    raise "VM has no EMS, unable to connect Floppy devices" unless self.ext_management_system
    run_command_via_parent(:vm_connect_floppy)
  end

  def connect_floppies
    raw_connect_floppies
  end

  def raw_disconnect_floppies
    raise "VM has no EMS, unable to disconnect Floppy devices" unless self.ext_management_system
    run_command_via_parent(:vm_disconnect_floppy)
  end

  def disconnect_floppies
    raw_disconnect_floppies
  end

  def raw_add_disk(disk_name, disk_size_mb)
    raise "VM has no EMS, unable to add disk" unless self.ext_management_system
    run_command_via_parent(:vm_add_disk, :diskName => disk_name, :diskSize => disk_size_mb)
  end

  def add_disk(disk_name, disk_size_mb)
    raw_add_disk(disk_name, disk_size_mb)
  end

  def spec_reconfigure(spec)
    raise "VM has no EMS, unable to apply reconfigure spec" unless self.ext_management_system
    run_command_via_parent(:vm_reconfigure, :spec => spec)
  end

end
