class ManageIQ::Providers::Openshift::ContainerManager::EventCatcherHawkular < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Openshift::ContainerManager  # unneccessary?  default `parent` should work?
  end
end
