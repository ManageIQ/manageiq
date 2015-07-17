module ManageIQ::Providers::Redhat::InfraManager::ProvisionViaIso::StateMachine
  def customize_destination
    message = "Starting New #{destination_type} Customization"
    _log.info("#{message} #{for_destination}")
    update_and_notify_parent(:message => message)

    configure_container
    attach_floppy_payload

    signal :boot_from_cdrom
  end

  def boot_from_cdrom
    message = "Booting from CDROM"
    _log.info("#{message} #{for_destination}")
    update_and_notify_parent(:message => message)

    begin
      get_provider_destination.boot_from_cdrom(iso_image.name)
    rescue Ovirt::VmNotReadyToBoot
      _log.info("#{destination_type} [#{dest_name}] is not yet ready to boot, will retry")
      requeue_phase
    else
      signal :poll_destination_powered_on_in_provider
    end
  end

  def post_provision
    update_and_notify_parent(:message => "Post Provisioning")

    get_provider_destination.detach_floppy

    signal :autostart_destination
  end
end
