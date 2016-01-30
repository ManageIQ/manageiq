class ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner
  def self.ems_class
    ManageIQ::Providers::Openshift::ContainerManager
  end
end
