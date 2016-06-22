class ManageIQ::Providers::Azure::NetworkManager::EventCatcher < ::MiqEventCatcher
  def self.ems_class
    ManageIQ::Providers::Azure::NetworkManager
  end

  def self.settings_name
    :event_catcher_azure_network
  end
end
