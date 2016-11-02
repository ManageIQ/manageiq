module ManageIQ::Providers::Redhat::InfraManager::Provision::Disk
  def configure_dialog_disks
    added_disks = options[:disk_scsi]
    return nil if added_disks.blank?

    options[:disks_add] = prepare_disks_for_add(added_disks)
  end

  def add_disks(disks)
    destination.ext_management_system.with_disk_attachments_service(destination) do |service|
      disks.each { |disk| service.add(disk) }
    end
  end

  def destination_disks_locked?
    destination.ext_management_system.with_provider_connection(:version => 4) do |connection|
      system_service = connection.system_service
      disks = system_service.vms_service.vm_service(destination.uid_ems).disk_attachments_service.list
      disks.each do |disk|
        fetched_disk = system_service.disks_service.disk_service(disk.id).get
        return true unless fetched_disk.try(:status) == "ok"
      end
    end

    false
  end

  private

  def prepare_disks_for_add(disks_spec)
    disks_spec.collect do |disk_spec|
      disk = prepare_disk_for_add(disk_spec)
      _log.info("disk: #{disk.inspect}")
      disk
    end.compact
  end

  def prepare_disk_for_add(disk_spec)
    storage_name = disk_spec[:datastore]
    raise MiqException::MiqProvisionError, "Storage is required for disk: <#{disk_spec.inspect}>" if storage_name.blank?

    storage = Storage.find_by(:name => storage_name)
    if storage.nil?
      raise MiqException::MiqProvisionError, "Unable to find storage: <#{storage_name}> for disk: <#{disk_spec.inspect}>"
    end

    da_options = {
      :size_in_mb       => disk_spec[:sizeInMB],
      :storage          => storage,
      :name             => disk_spec[:filename],
      :thin_provisioned => disk_spec[:backing] && disk_spec[:backing][:thinprovisioned],
      :bootable         => disk_spec[:bootable],
      :interface        => disk_spec[:interface]
    }

    disk_attachment_builder = ManageIQ::Providers::Redhat::InfraManager::DiskAttachmentBuilder.new(da_options)
    disk_attachment_builder.disk_attachment
  end
end
