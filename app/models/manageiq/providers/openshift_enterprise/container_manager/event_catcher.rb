class ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner
  def self.ems_class
    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager
  end
end
