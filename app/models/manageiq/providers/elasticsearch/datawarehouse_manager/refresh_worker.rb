module ManageIQ::Providers
  class Elasticsearch::DatawarehouseManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
    require_nested :Runner

    def self.ems_class
      ManageIQ::Providers::Elasticsearch::DatawarehouseManager
    end
  end
end
