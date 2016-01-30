class ManageIQ::Providers::Atomic::ContainerManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner
  def self.ems_class
    ManageIQ::Providers::Atomic::ContainerManager
  end
end
