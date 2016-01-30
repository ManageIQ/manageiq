class ManageIQ::Providers::AtomicEnterprise::ContainerManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::AtomicEnterprise::ContainerManager
  end
end
