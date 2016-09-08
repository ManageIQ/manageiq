class ManageIQ::Providers::StorageManager::SwiftStorageManager::EventCatcher < ::MiqEventCatcher
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::StorageManager::SwiftStorageManager
  end

  def self.settings_name
    :event_catcher_swift_storage
  end

  def self.all_valid_ems_in_zone
    super.select do |ems|
      ems.event_monitor_available?.tap do |available|
        _log.info("Event Monitor unavailable for #{ems.name}.  Check log history for more details.") unless available
      end
    end
  end
end
