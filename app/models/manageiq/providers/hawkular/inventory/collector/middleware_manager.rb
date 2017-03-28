module ManageIQ::Providers
  class Hawkular::Inventory::Collector::MiddlewareManager < ManagerRefresh::Inventory::Collector
    require 'hawkular/hawkular_client'
    include ::Hawkular::ClientUtils

    def connection
      @connection ||= manager.connect
    end

    def feeds
      connection.inventory.list_feeds
    end

    def eaps(feed)
      path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id          => hawk_escape_id(feed),
                                                      :resource_type_id => hawk_escape_id('WildFly Server'))
      connection.inventory.list_resources_for_type(path.to_s, :fetch_properties => true)
    end

    def domains(feed)
      path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id          => hawk_escape_id(feed),
                                                      :resource_type_id => hawk_escape_id('Domain Host'))
      host_controllers = connection.inventory.list_resources_for_type(path.to_s, :fetch_properties => true)

      # filter only the domain controllers
      host_controllers.select { |host_controller| host_controller.properties['Is Domain Controller'] == 'true' }
    end

    def server_groups(feed)
      path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id          => hawk_escape_id(feed),
                                                      :resource_type_id => hawk_escape_id('Domain Server Group'))
      connection.inventory.list_resources_for_type(path.to_s, :fetch_properties => true)
    end

    def domain_servers(feed)
      path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id          => hawk_escape_id(feed),
                                                      :resource_type_id => hawk_escape_id('Domain WildFly Server'))
      connection.inventory.list_resources_for_type(path.to_s, :fetch_properties => true)
    end

    def child_resources(resource_path, recursive = false)
      connection.inventory.list_child_resources(resource_path, recursive)
    end

    def machine_id(feed)
      os_property_for(feed, 'Machine Id')
    end

    def container_id(feed)
      os_property_for(feed, 'Container Id')
    end

    def config_data_for_resource(resource_path)
      connection.inventory.get_config_data_for_resource(resource_path)
    end

    def metrics_for_metric_type(metric_path)
      connection.inventory.list_metrics_for_metric_type(metric_path)
    end

    def raw_availability_data(*args)
      connection.metrics.avail.raw_data(*args)
    end

    private
    def os_property_for(feed, property)
      os_resource_for(feed)
        .try(:properties)
        .try { |prop| prop[property] }
    end

    def os_resource_for(feed)
      os = os_for(feed)
      unless os.nil?
        os_resources = connection.inventory.list_resources_for_type(os.path, true)
        unless os_resources.nil? || os_resources.empty?
          return os_resources.first
        end
        $mw_log.warn "Found no OS resources for resource type #{os.path}"
      end
      nil
    end

    def os_for(feed)
      resource_types = connection.inventory.list_resource_types(hawk_escape_id(feed))
      os_types = resource_types.select { |item| item.id.include? 'Operating System' }
      unless os_types.nil? || os_types.empty?
        return os_types.first
      end

      $mw_log.warn "Found no OS resource types for feed #{feed}"
      nil
    end
  end
end
