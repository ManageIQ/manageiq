module ManageIQ::Providers
  class BaseManager < ExtManagementSystem
    require_nested :Refresher

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

    def http_proxy_uri
      proxy = VMDB::Util.http_proxy_uri(emstype.to_s.to_sym)

      unless proxy
        proxy = VMDB::Util.http_proxy_uri
      end

      proxy
    end
  end
end
