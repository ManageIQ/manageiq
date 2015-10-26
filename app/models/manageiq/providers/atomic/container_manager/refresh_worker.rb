class ManageIQ::Providers::Atomic::ContainerManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner
  def self.ems_class
    ManageIQ::Providers::Atomic::ContainerManager
  end
end
