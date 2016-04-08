class ManageIQ::Providers::Azure::NetworkManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Azure::NetworkManager
  end

  def self.settings_name
    :ems_refresh_worker_azure_network
  end
end
