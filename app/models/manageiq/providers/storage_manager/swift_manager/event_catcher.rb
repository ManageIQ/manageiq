class ManageIQ::Providers::StorageManager::SwiftManager::EventCatcher < ::MiqEventCatcher
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::StorageManager::SwiftManager
  end

  def self.settings_name
    :event_catcher_swift
  end
end
