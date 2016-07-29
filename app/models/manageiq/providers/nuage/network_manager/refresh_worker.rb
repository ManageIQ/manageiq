class ManageIQ::Providers::Nuage::NetworkManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Nuage::NetworkManager
  end
end
