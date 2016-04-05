class ManageIQ::Providers::Amazon::NetworkManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Amazon::NetworkManager
  end

  def self.settings_name
    :ems_refresh_worker_amazon_network
  end
end
