require 'hawkular/hawkular_client'

module ManageIQ::Providers
  class Hawkular::Inventory::Collector::MiddlewareManager < ManagerRefresh::Inventory::Collector
    include ::Hawkular::ClientUtils

    def connection
      @connection ||= manager.connect
    end

    def feeds
      connection.inventory.list_feeds
    end

    def eaps(feed)
      resources_for(feed, 'WildFly Server')
    end

    def domains(feed)
      resources_for(feed, 'Domain Host')
        .select { |host| host.properties['Is Domain Controller'] == 'true' }
    end

    def server_groups(feed)
      resources_for(feed, 'Domain Server Group')
    end

    def domain_servers(feed)
      resources_for(feed, 'Domain WildFly Server')
    end

    def child_resources(resource_path, recursive = false)
      manager.child_resources(resource_path, recursive)
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
      os_for(feed)
        .try { |os| connection.inventory.list_resources_for_type(os.path, true) }
        .presence
        .try(:first)
    end

    def os_for(feed)
      connection
        .inventory
        .list_resource_types(hawk_escape_id(feed))
        .select { |item| item.id.include? 'Operating System' }
        .first
    end

    def resources_for(feed, resource_type_path)
      path = ::Hawkular::Inventory::CanonicalPath.new(
        :feed_id          => hawk_escape_id(feed),
        :resource_type_id => hawk_escape_id(resource_type_path)
      )
      connection.inventory.list_resources_for_type(path.to_s, :fetch_properties => true)
    end
  end
end
