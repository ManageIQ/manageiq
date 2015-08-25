class ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_dependency 'manageiq/providers/kubernetes/container_manager/refresh_worker/runner'
  def self.ems_class
    ManageIQ::Providers::Kubernetes::ContainerManager
  end
end
