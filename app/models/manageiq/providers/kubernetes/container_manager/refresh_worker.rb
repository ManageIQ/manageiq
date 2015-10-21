class ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner
  def self.ems_class
    ManageIQ::Providers::Kubernetes::ContainerManager
  end
end
