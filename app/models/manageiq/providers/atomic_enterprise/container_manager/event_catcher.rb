class ManageIQ::Providers::AtomicEnterprise::ContainerManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner
  def self.ems_class
    ManageIQ::Providers::AtomicEnterprise::ContainerManager
  end
end
