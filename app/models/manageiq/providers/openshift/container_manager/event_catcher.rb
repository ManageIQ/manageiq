class ManageIQ::Providers::Openshift::ContainerManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_dependency 'manageiq/providers/openshift/container_manager/event_catcher/runner'
  def self.ems_class
    ManageIQ::Providers::Openshift::ContainerManager
  end
end
