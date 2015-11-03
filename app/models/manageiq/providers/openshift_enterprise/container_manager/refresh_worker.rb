class ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager
  end
end
