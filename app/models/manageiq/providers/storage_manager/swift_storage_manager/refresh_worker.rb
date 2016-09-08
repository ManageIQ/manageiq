class ManageIQ::Providers::StorageManager::SwiftStorageManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::StorageManager::SwiftStorageManager
  end

  def self.settings_name
    :ems_refresh_worker_swift_storage
  end
end
