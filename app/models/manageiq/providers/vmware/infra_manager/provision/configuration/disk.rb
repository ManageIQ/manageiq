module ManageIQ::Providers::Vmware::InfraManager::Provision::Configuration::Disk
  def build_config_disk_spec(vmcs)
    new_disks = get_new_disks
    return if new_disks.blank?
    _log.info "New disk info: <#{new_disks.inspect}>"

    source_controllers = get_scsi_controller_info
    _log.info "Source SCSI controller info: <#{source_controllers.inspect}>"

    new_disks.each do |disk|
      bus_pos = disk[:bus]

      # Add new SCSI controller if missing for the requested bus index
      if source_controllers[bus_pos].blank?
        scsi_controller_idx = get_next_device_idx
        add_scsi_controller(vmcs, bus_pos, scsi_controller_idx)
        source_controllers[bus_pos] = {"key" => scsi_controller_idx}
      end

      add_disk(vmcs, disk, source_controllers[bus_pos], get_next_device_idx)
    end
  end

  def get_scsi_controller_info
    inventory_hash = source.with_provider_connection do |vim|
      vim.virtualMachineByMor(source.ems_ref_obj)
    end

    devs = inventory_hash.fetch_path("config", "hardware", "device") || []
    devs.each_with_object({}) do |dev, h|
      next unless dev.fetch_path("deviceInfo", "label").to_s =~ /^SCSI\s[Cc]ontroller\s.*$/
      h[dev['busNumber'].to_i] = dev
    end
  end

  def add_scsi_controller(vmcs, busNumber, new_dev_key)
    controller_settings = options[:ctrl_scsi].to_miq_a.detect { |c| c[:busnumber] == busNumber.to_i } || {}
    _log.info "Adding SCSI controller on bus <#{busNumber}>  Settings: <#{controller_settings.inspect}>"
    device_type = get_config_spec_value(controller_settings, 'VirtualLsiLogicController', nil, [:devicetype])
    add_device_config_spec(vmcs, VirtualDeviceConfigSpecOperation::Add) do |vdcs|
      vdcs.device = VimHash.new(device_type) do |vDev|
        vDev.sharedBus = get_config_spec_value(controller_settings, 'noSharing', 'VirtualSCSISharing', [:sharedbus])
        vDev.busNumber = busNumber
        vDev.key = new_dev_key
      end
    end
  end

  def add_disk(vmcs, disk, controller, new_dev_key)
    # Note: backing_filename is a fully qualified filename including datastore.
    filename = (disk[:filename].blank? ? "#{dest_name}_#{disk[:bus]}_#{disk[:pos]}" : File.basename(disk[:filename], ".*")) + ".vmdk"
    datastore_name = disk[:datastore].blank? ? dest_datastore : disk[:datastore]
    backing_filename = File.join("[#{datastore_name}] ", dest_name, filename)

    add_device_config_spec(vmcs, VirtualDeviceConfigSpecOperation::Add) do |vdcs|
      vdcs.fileOperation = VirtualDeviceConfigSpecFileOperation::Create
      vdcs.device = VimHash.new("VirtualDisk") do |vDev|
        vDev.key            = new_dev_key
        vDev.capacityInKB   = disk[:sizeInMB].to_i * 1024
        vDev.controllerKey  = controller["key"]
        vDev.unitNumber     = disk[:pos]
        # The following doesn't seem to work.
        vDev.deviceInfo = VimHash.new("Description") do |desc|
          desc.label    = disk[:label]
          desc.summary  = disk[:summary]
        end if disk[:label] || disk[:summary]
        vDev.connectable = VimHash.new("VirtualDeviceConnectInfo") do |con|
          con.allowGuestControl = get_config_spec_value(disk, 'false', nil, [:connectable, :allowguestcontrol])
          con.startConnected    = get_config_spec_value(disk, 'true',  nil, [:connectable, :startconnected])
          con.connected         = get_config_spec_value(disk, 'true',  nil, [:connectable, :connected])
        end
        vDev.backing = VimHash.new("VirtualDiskFlatVer2BackingInfo") do |bck|
          bck.diskMode        = get_config_spec_value(disk, 'persistent', 'VirtualDiskMode', [:backing, :diskmode])
          bck.split           = get_config_spec_value(disk, 'false', nil, [:backing, :split])
          bck.thinProvisioned = get_config_spec_value(disk, 'false', nil, [:backing, :thinprovisioned])
          bck.writeThrough    = get_config_spec_value(disk, 'false', nil, [:backing, :writethrough])
          bck.fileName        = backing_filename
        end
      end
    end
  end
end
