module MiqProvisionAmazon::StateMachine
  def customize_destination
    message = "Setting New #{destination_type} Name"
    $log.info("MIQ(#{self.class.name}#customize_destination) #{message} #{for_destination}")
    update_and_notify_parent(:message => message)

    destination.set_custom_field("Name", dest_name)
    destination.update_attributes(:name => dest_name)

    super
  end
end
