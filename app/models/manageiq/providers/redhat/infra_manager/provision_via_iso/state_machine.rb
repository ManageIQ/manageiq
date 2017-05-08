module ManageIQ::Providers::Redhat::InfraManager::ProvisionViaIso::StateMachine
  def configure_destination
    attach_floppy_payload
    signal :boot_from_cdrom
  end

  def customize_guest
    attach_floppy_payload
    signal :boot_from_cdrom
  end

  def boot_from_cdrom
    message = "Booting from CDROM"
    _log.info("#{message} #{for_destination}")
    update_and_notify_parent(:message => message)

    begin
      ext_management_system.ovirt_services.vm_boot_from_cdrom(self, iso_image.name)
    rescue ManageIQ::Providers::Redhat::InfraManager::OvirtServices::VmNotReadyToBoot
      _log.info("#{destination_type} [#{dest_name}] is not yet ready to boot, will retry")
      requeue_phase
    else
      signal :poll_destination_powered_on_in_provider
    end
  end

  def post_provision
    update_and_notify_parent(:message => "Post Provisioning")

    ext_management_system.ovirt_services.detach_floppy(self)

    signal :autostart_destination
  end
end
