module ManageIQ::Providers
  class BaseManager < ExtManagementSystem
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

    # Return the names of all of the manager types e.g.: InfraManager, CloudManager, etc...
    def self.manager_type_names
      @manager_type_names ||= subclasses.map { |k| k.name.gsub("ManageIQ::Providers::", "") }
    end

    def refresher
      self.class::Refresher
    end

    def http_proxy_uri
      self.class.http_proxy_uri
    end

    def http_proxy
      self.class.http_proxy
    end

    def console_url
      raise NotImplementedError, _("console_url must be implemented in a subclass")
    end

    # copy my attributes to a child manager
    # child managers need to be in lock step with this manager
    def propagate_child_manager_attributes(child, name = nil)
      child.name                 = name if name
      child.zone_id              = zone_id
      child.zone_before_pause_id = zone_before_pause_id
      child.enabled              = enabled
      child.provider_region      = provider_region
      child.tenant_id            = tenant_id

      child
    end

    def self.http_proxy_uri
      VMDB::Util.http_proxy_uri(ems_type.try(:to_sym)) || VMDB::Util.http_proxy_uri
    end

    def self.http_proxy
      VMDB::Util.http_proxy(ems_type.try(:to_sym)) || VMDB::Util.http_proxy
    end

    def self.filtered_event_names
      Array(::Settings.ems["ems_#{ems_type}"].try(:blacklisted_event_names))
    end
    delegate :filtered_event_names, :to => :class

    # Returns a description of the options that are stored in "options" field.
    def self.options_description
      {}
    end
  end
end
