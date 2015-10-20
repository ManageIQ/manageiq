class ManageIQ::Providers::Openshift::ContainerManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner
  def self.ems_class
    ManageIQ::Providers::Openshift::ContainerManager
  end
end
