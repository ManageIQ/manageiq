module ManageIQ::Providers
  class Hawkular::DatawarehouseManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
    require_nested :Runner

    def self.ems_class
      ManageIQ::Providers::Hawkular::DatawarehouseManager
    end
  end
end
