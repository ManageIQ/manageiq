class ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner
  def self.ems_class
    ManageIQ::Providers::Kubernetes::ContainerManager
  end
end
