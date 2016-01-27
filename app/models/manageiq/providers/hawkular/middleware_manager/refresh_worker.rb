class ManageIQ::Providers::Hawkular::MiddlewareManager::RefreshWorker <
    ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Hawkular::MiddlewareManager
  end
end
