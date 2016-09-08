class ManageIQ::Providers::StorageManager::CinderStorageManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::StorageManager::CinderStorageManager
  end

  def self.settings_name
    :ems_refresh_worker_cinder_storage
  end
end
