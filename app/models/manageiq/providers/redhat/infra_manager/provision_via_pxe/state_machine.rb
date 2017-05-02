module ManageIQ::Providers::Redhat::InfraManager::ProvisionViaPxe::StateMachine
  def configure_destination
    signal :create_pxe_configuration_file
  end

  def customize_guest
    signal :create_pxe_configuration_file
  end

  def create_pxe_configuration_file
    message = "Generating PXE and Customization Files on PXE Server"
    _log.info("#{message} #{for_destination}")
    update_and_notify_parent(:message => message)
    create_pxe_files

    signal :boot_from_network
  end

  def boot_from_network
    message = "Booting from Network"
    _log.info("#{message} #{for_destination}")
    update_and_notify_parent(:message => message)

    begin
      destination.ext_management_system.ovirt_services.vm_boot_from_network(self)
    rescue ManageIQ::Providers::Redhat::InfraManager::OvirtServices::VmNotReadyToBoot
      _log.info("#{destination_type} [#{dest_name}] is not yet ready to boot, will retry")
      requeue_phase
    else
      signal :poll_destination_powered_on_in_provider
    end
  end

  def post_provision
    update_and_notify_parent(:message => "Post Provisioning")

    if get_option(:stateless)
      message = "Stateless, NOT deleting PXE and Customization Files on PXE Server"
      _log.info("#{message} #{for_destination}")
    else
      message = "Deleting PXE and Customization Files on PXE Server"
      _log.info("#{message} #{for_destination}")
      update_and_notify_parent(:message => message)
      delete_pxe_files
    end

    signal :autostart_destination
  end
end
