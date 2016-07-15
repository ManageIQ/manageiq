module ManageIQ::Providers::Azure::CloudManager::Provision::StateMachine
  def customize_destination
    message = "Customizing #{for_destination}"
    _log.info("#{message} #{for_destination}")
    update_and_notify_parent(:message => message)

    signal :post_create_destination
  end
end
