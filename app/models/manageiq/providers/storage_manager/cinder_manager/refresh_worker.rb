class ManageIQ::Providers::StorageManager::CinderManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.settings_name
    :ems_refresh_worker_cinder
  end
end
