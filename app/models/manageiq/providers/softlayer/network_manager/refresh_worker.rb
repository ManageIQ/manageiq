class ManageIQ::Providers::SoftLayer::NetworkManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::SoftLayer::NetworkManager
  end

  def self.settings_name
    :ems_refresh_worker_softlayer_network
  end
end
