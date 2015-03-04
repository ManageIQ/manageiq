module EmsRefresh
  module Parsers
    class OpenstackInfra < Infra
      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, _options = nil)
        @ems               = ems
        @connection        = ems.connect
        @data              = {}
        @data_index        = {}
        @host_hash_by_name = {}

        @known_flavors = Set.new

        @os_handle                  = ems.openstack_handle
        @compute_service            = @connection # for consistency
        @baremetal_service          = @os_handle.detect_baremetal_service
        @baremetal_service_name     = @os_handle.baremetal_service_name
        @orchestration_service      = @os_handle.detect_orchestration_service
        @orchestration_service_name = @os_handle.orchestration_service_name
      end

      def ems_inv_to_hashes
        log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data" \
                     " for EMS name: [#{@ems.name}] id: [#{@ems.id}]"
        $fog_log.info("#{log_header}...")

        load_hosts

        $fog_log.info("#{log_header}...Complete")
        @data
      end

      private

      def servers
        @servers ||= @connection.servers_for_accessible_tenants
      end

      def hosts
        @hosts ||= @baremetal_service.nodes.details
      end

      def hosts_ports
        @hosts_ports ||= @baremetal_service.ports.details
      end

      def resources
        return @resources if @resources

        resources = []
        @orchestration_service.stacks.each do |stack|
          # Nested depth 50 just for sure, although nobody should nest templates that much
          all_stack_resources = @orchestration_service.list_resources(stack, :nested_depth => 50)
          # Filtering just OS::Nova::Server, which is important to us for getting Purpose of the node
          # (compute, controller, etc.).
          resources += all_stack_resources.body['resources'].select { |x| x["resource_type"] == 'OS::Nova::Server' }
        end
        @resources = resources
      end

      def load_hosts
        # Servers contains assigned IP address of hosts, there can be only
        # one nova server per host, only if the host is provisioned.
        indexed_servers = {}
        servers.each { |s| indexed_servers[s.id] = s }

        # Hosts ports contains MAC addresses of host interfaces. There can
        # be multiple interfaces for each host
        indexed_hosts_ports = {}
        hosts_ports.each { |p|  (indexed_hosts_ports[p.uuid] ||= []) <<  p }

        # Indexed Heat resources, we are interested only in OS::Nova::Server
        indexed_resources = {}
        resources.each { |p| indexed_resources[p['physical_resource_id']] = p }

        process_collection(hosts, :hosts) do  |host|
          parse_host(host, indexed_servers, indexed_hosts_ports, indexed_resources)
        end
      end

      def parse_host(host, indexed_servers, _indexed_hosts_ports, indexed_resources)
        uid = host.uuid
        host_name = identify_host_name(indexed_resources, host.instance_uuid, uid)

        new_result = {
          :name             => host_name,
          :type             => 'HostOpenstackInfra',
          :uid_ems          => uid,
          :ems_ref          => uid,
          :ems_ref_obj      => host.instance_uuid,
          :operating_system => {:product_name => 'linux'},
          :vmm_vendor       => 'RedHat',
          :vmm_product      => identify_product(indexed_resources, host.instance_uuid),
          :ipaddress        => identify_primary_ip_address(host, indexed_servers),
          :mac_address      => identify_primary_mac_address(host, indexed_servers),
          :ipmi_address     => identify_ipmi_address(host),
          :power_state      => lookup_power_state(host.power_state),
          :connection_state => lookup_connection_state(host.power_state),
          :hardware         => process_host_hardware(host)
        }

        return uid, new_result
      end

      def process_host_hardware(host)
        {
          :memory_cpu    => normalize_blank_property(host.properties['memory_mb']),
          :disk_capacity => normalize_blank_property(host.properties['local_gb']),
          :numvcpus      => normalize_blank_property_num(host.properties['cpus'])
        }
      end

      def server_address(server, key)
        # TODO(lsmola) Nova is missing information which address is primary now,
        # so just taking first. We need to figure out how to identify it if
        # there are multiple.
        server.addresses.try(:[], 'ctlplane').try(:[], 0).try(:[], key) if server
      end

      def get_purpose(indexed_resources, instance_uuid)
        indexed_resources.fetch_path(instance_uuid, 'resource_name')
      end

      def identify_product(indexed_resources, instance_uuid)
        purpose = get_purpose(indexed_resources, instance_uuid)
        return nil unless purpose

        if purpose == 'NovaCompute'
          'rhel (Nova Compute hypervisor)'
        else
          "rhel (No hypervisor, Host Type is #{purpose})"
        end
      end

      def identify_host_name(indexed_resources, instance_uuid, uid)
        purpose = get_purpose(indexed_resources, instance_uuid)
        return uid unless purpose

        "#{uid} (#{purpose})"
      end

      def identify_primary_mac_address(host, indexed_servers)
        server_address(indexed_servers[host.instance_uuid], 'OS-EXT-IPS-MAC:mac_addr')
      end

      def identify_primary_ip_address(host, indexed_servers)
        server_address(indexed_servers[host.instance_uuid], 'addr')
      end

      def identify_ipmi_address(host)
        host.driver_info["ipmi_address"]
      end

      def lookup_power_state(power_state_input)
        case power_state_input
        when "power on"               then "on"
        when "power off", "rebooting" then "off"
        else                               "unknown"
        end
      end

      def lookup_connection_state(power_state_input)
        case power_state_input
        when "power on"               then "connected"
        when "power off", "rebooting" then "disconnected"
        else                               "disconnected"
        end
      end

      #
      # Helper methods
      #

      def normalize_blank_property_num(property)
        property.try(:to_i)
      end

      def normalize_blank_property(property)
        property.blank? ? nil : property
      end

      def process_collection(collection, key)
        @data[key] ||= []
        return if collection.nil?

        collection.each do |item|
          uid, new_result = yield(item)

          @data[key] << new_result
          @data_index.store_path(key, uid, new_result)
        end
      end
    end
  end
end
