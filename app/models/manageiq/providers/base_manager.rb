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

    def self.catalog_types
      {}
    end
    delegate :catalog_types, :to => :class

    def refresher
      self.class::Refresher
    end

    def http_proxy_uri
      self.class.http_proxy_uri
    end

    def self.http_proxy_uri
      VMDB::Util.http_proxy_uri(ems_type.try(:to_sym)) || VMDB::Util.http_proxy_uri
    end

    def self.default_blacklisted_event_names
      Array(::Settings.ems["ems_#{provider_name.underscore}"].try(:blacklisted_event_names))
    end

    # Returns a description of the options that are stored in "options" field.
    def self.options_description
      {}
    end
  end

  def self.display_name(number = 1)
    n_('Manager', 'Managers', number)
  end
end
