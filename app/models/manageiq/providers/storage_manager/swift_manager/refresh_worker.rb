class ManageIQ::Providers::StorageManager::SwiftManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::StorageManager::SwiftManager
  end

  def self.settings_name
    :ems_refresh_worker_swift
  end
end
