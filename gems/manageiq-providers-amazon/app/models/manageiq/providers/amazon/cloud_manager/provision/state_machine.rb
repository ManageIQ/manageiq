module ManageIQ::Providers::Amazon::CloudManager::Provision::StateMachine
  def customize_destination
    message = "Setting New #{destination_type} Name"
    _log.info("#{message} #{for_destination}")
    update_and_notify_parent(:message => message)

    destination.set_custom_field("Name", dest_name)
    destination.update_attributes(:name => dest_name)

    super
  end
end
