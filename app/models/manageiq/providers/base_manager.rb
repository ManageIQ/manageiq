module ManageIQ::Providers
  class BaseManager < ExtManagementSystem
    require_nested :Refresher

    include Inflector::Methods

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
      VMDB::Util.http_proxy_uri(emstype.try(:to_sym)) || VMDB::Util.http_proxy_uri
    end

    def self.default_blacklisted_event_names
      Array(::Settings.ems["ems_#{provider_name.underscore}"].try(:blacklisted_event_names))
    end
  end
end
