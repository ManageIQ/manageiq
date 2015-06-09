module MiqProvisionRedhatViaPxe::StateMachine
  def customize_destination
    message = "Starting New #{destination_type} Customization"
    $log.info("MIQ(#{self.class.name}#customize_destination) #{message} #{for_destination}")
    update_and_notify_parent(:message => message)
    configure_container

    signal :create_pxe_configuration_file
  end

  def create_pxe_configuration_file
    message = "Generating PXE and Customization Files on PXE Server"
    $log.info("MIQ(#{self.class.name}#create_pxe_configuration_file) #{message} #{for_destination}")
    update_and_notify_parent(:message => message)
    create_pxe_files

    signal :boot_from_network
  end

  def boot_from_network
    message = "Booting from Network"
    $log.info("MIQ(#{self.class.name}#boot_from_network) #{message} #{for_destination}")
    update_and_notify_parent(:message => message)

    begin
      get_provider_destination.boot_from_network
    rescue Ovirt::VmNotReadyToBoot
      $log.info("MIQ(#{self.class.name}#boot_from_network) #{destination_type} [#{dest_name}] is not yet ready to boot, will retry")
      requeue_phase
    else
      # Temporarily set the database raw_power_state in case the refresh has not come along yet.
      destination.update_attributes(:raw_power_state => "wait_for_launch")

      signal :poll_destination_powered_off_in_provider
    end
  end

  def post_provision
    update_and_notify_parent(:message => "Post Provisioning")

    if get_option(:stateless)
      message = "Stateless, NOT deleting PXE and Customization Files on PXE Server"
      $log.info("MIQ(#{self.class.name}#post_provision_via_pxe) #{message} #{for_destination}")
    else
      message = "Deleting PXE and Customization Files on PXE Server"
      $log.info("MIQ(#{self.class.name}#post_provision_via_pxe) #{message} #{for_destination}")
      update_and_notify_parent(:message => message)
      delete_pxe_files
    end

    signal :autostart_destination
  end
end
