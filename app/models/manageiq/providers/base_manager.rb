module ManageIQ::Providers
  class BaseManager < ExtManagementSystem
    def self.metrics_collector_queue_name
      self::MetricsCollectorWorker.default_queue_name
    end

    def metrics_collector_queue_name
      self.class.metrics_collector_queue_name
    end

    def ext_management_system
      self
    end

    def refresher
      self.class::Refresher
    end
  end
end

require_dependency 'manageiq/providers/base_manager/refresher'
