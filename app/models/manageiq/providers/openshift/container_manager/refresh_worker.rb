class ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_dependency 'manageiq/providers/openshift/container_manager/refresh_worker/runner'
  def self.ems_class
    ManageIQ::Providers::Openshift::ContainerManager
  end
end
