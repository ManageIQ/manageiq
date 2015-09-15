class ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_dependency 'manageiq/providers/kubernetes/container_manager/event_catcher/runner'
  def self.ems_class
    ManageIQ::Providers::Kubernetes::ContainerManager
  end
end
