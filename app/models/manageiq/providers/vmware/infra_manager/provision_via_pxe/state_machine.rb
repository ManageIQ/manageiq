module ManageIQ::Providers::Vmware::InfraManager::ProvisionViaPxe::StateMachine
  def customize_destination
    _log.info("Post-processing #{destination_type} id: [#{destination.id}], name: [#{dest_name}]")
    update_and_notify_parent(:message => "Starting New #{destination_type} Customization")

    set_cpu_and_memory_allocation(destination) if reconfigure_hardware_on_destination?

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
      # Default Boot Order (Disk, CDROM, Network)
      #  Since the first 2 are empty, it should boot from the network
      destination.start
    rescue
      _log.info("#{destination_type} [#{dest_name}] is not yet ready to boot, will retry")
      requeue_phase
    else
      # Temporarily set the database raw_power_state in case the refresh has not come along yet.
      destination.update_attributes(:raw_power_state => "wait_for_launch")

      signal :poll_destination_powered_off_in_vmdb
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
