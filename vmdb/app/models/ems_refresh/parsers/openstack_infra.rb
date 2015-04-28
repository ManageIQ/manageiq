module EmsRefresh
  module Parsers
    class OpenstackInfra < Infra
      include EmsRefresh::Parsers::OpenstackCommon::Images
      include EmsRefresh::Parsers::OpenstackCommon::OrchestrationStacks

      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, _options = nil)
        @ems               = ems
        @connection        = ems.connect
        @data              = {}
        @data_index        = {}
        @host_hash_by_name = {}
        @resource_to_stack = {}

        @known_flavors = Set.new

        @os_handle              = ems.openstack_handle
        @compute_service        = @connection # for consistency
        @baremetal_service      = @os_handle.detect_baremetal_service
        @baremetal_service_name = @os_handle.baremetal_service_name
        @orchestration_service      = @os_handle.detect_orchestration_service
        @orchestration_service_name = @os_handle.orchestration_service_name
        @image_service        = @os_handle.detect_image_service
        @image_service_name   = @os_handle.image_service_name
      end

      def ems_inv_to_hashes
        log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data" \
                     " for EMS name: [#{@ems.name}] id: [#{@ems.id}]"
        $fog_log.info("#{log_header}...")

        load_hosts
        get_images
        load_orchestration_stacks
        # Cluster processing needs to run after host and stacks processing
        get_clusters

        $fog_log.info("#{log_header}...Complete")
        @data
      end

      private

      def all_server_resources
        return @all_server_resources if @all_server_resources

        resources = []
        stacks.each do |stack|
          all_stack_resources = stack_resources(stack)
          # Filtering just OS::Nova::Server, which is important to us for getting Purpose of the node
          # (compute, controller, etc.).
          resources += all_stack_resources.select { |x| x["resource_type"] == 'OS::Nova::Server' }
        end
        @all_server_resources = resources
      end

      def servers
        @servers ||= @connection.servers_for_accessible_tenants
      end

      def hosts
        @hosts ||= @baremetal_service.nodes.details
      end

      def clouds
        @ems.provider.try(:cloud_ems)
      end

      def cloud_ems_hosts_attributes
        hosts_attributes = []
        return hosts_attributes unless clouds

        clouds.each do |cloud_ems|
          connection = cloud_ems.connect
          compute_hosts  = connection.hosts.select { |x| x.service_name == "compute" }
          compute_hosts.each do |compute_host|
            # We need to take correct zone id from correct provider, since the zone name can be the same
            # across providers
            availability_zone_id = cloud_ems.availability_zones.where(:name => compute_host.zone).first.try(:id)
            hosts_attributes << {:host_name => compute_host.host_name, :availability_zone_id => availability_zone_id}
          end
        end
        hosts_attributes
      end

      def hosts_ports
        @hosts_ports ||= @baremetal_service.ports.details
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
        all_server_resources.each { |p| indexed_resources[p['physical_resource_id']] = p }

        process_collection(hosts, :hosts) do  |host|
          parse_host(host, indexed_servers, indexed_hosts_ports, indexed_resources, cloud_ems_hosts_attributes)
        end
      end

      def parse_lscpu(lscpu_data)
        parsed_data = {}

        lscpu_data.each_line do |line|
          parts = line.split(/:/)
          value = parts[1].try(:chomp).try(:strip)
          key = case parts[0]
                when 'Socket(s)'          then 'numvcpus'
                when 'Core(s) per socket' then 'cores_per_socket'
                when 'CPU MHz'            then 'cpu_speed'
                when 'Model name'         then 'cpu_type'
                end
          parsed_data[key] = value
        end
        parsed_data
      end

      def parse_dmidecode(dmidecode_data)
        parsed_data = {}

        dmidecode_data.each_line do |line|
          parts = line.split(/:/)
          value = parts[1].try(:chomp).try(:strip)
          key = case parts[0].strip
                when 'Manufacturer'  then 'manufacturer'
                when 'Product Name'  then 'model'
                when 'Version'       then 'guest_os_full_name'
                when 'Family'        then 'guest_os'
                when 'Serial Number' then 'service_tag'
                end
          parsed_data[key] = value
        end
        parsed_data
      end

      def get_extra_host_attributes!(host, hostname)
        # TODO(lsmola) in RHOS7 we can get this stuff from ironic, but now we need to hack it. This will need to
        # obtain host from DB, so it requires already existing host. So it will be always filled second refresh.
        # Once RHOS7 Ironic is here, we need to revisit indexes in extra data, that is changing a lot, then delete this
        host_for_ssh = HostOpenstackInfra.new(:hostname => hostname)
        host_for_ssh.ext_management_system = @ems

        begin
          host_for_ssh.connect_ssh do |ssu|
            parsed_lscpu = parse_lscpu(ssu.shell_exec("lscpu"))
            parsed_dmidecode = parse_dmidecode(ssu.shell_exec("dmidecode | grep -A8 'System Information'"))

            host.properties.merge!(parsed_lscpu)
            host.properties.merge!(parsed_dmidecode)
          end
        rescue Exception
          # Log the error if SSH is not accessible, but keep going in refresh
          $log.error "host.connect_ssh: SSH connection failed for [#{host_for_ssh.hostname}] with [#{$!.class}: #{$!}]"
        end
      end

      def parse_host(host, indexed_servers, _indexed_hosts_ports, indexed_resources, cloud_hosts_attributes)
        uid                 = host.uuid
        host_name           = identify_host_name(indexed_resources, host.instance_uuid, uid)
        hypervisor_hostname = identify_hypervisor_hostname(host, indexed_servers)
        ip_address          = identify_primary_ip_address(host, indexed_servers)
        hostname            = ip_address

        # Get the extra attributes from ssh if available
        get_extra_host_attributes!(host, hostname) if hostname

        # Get the cloud_host_attributes by hypervisor hostname, only compute hosts can get this
        cloud_host_attributes = cloud_hosts_attributes.select do |x|
          hypervisor_hostname && x[:host_name].include?(hypervisor_hostname.downcase)
        end
        cloud_host_attributes = cloud_host_attributes.first if cloud_host_attributes

        new_result = {
          :name                 => host_name,
          :type                 => 'HostOpenstackInfra',
          :uid_ems              => uid,
          :ems_ref              => uid,
          :ems_ref_obj          => host.instance_uuid,
          :operating_system     => {:product_name => 'linux'},
          :vmm_vendor           => 'RedHat',
          :vmm_product          => identify_product(indexed_resources, host.instance_uuid),
          :vmm_version          => normalize_blank_property(host.properties['guest_os_full_name']),
          :ipaddress            => ip_address,
          :hostname             => hostname,
          :mac_address          => identify_primary_mac_address(host, indexed_servers),
          :ipmi_address         => identify_ipmi_address(host),
          :power_state          => lookup_power_state(host.power_state),
          :connection_state     => lookup_connection_state(host.power_state),
          :hardware             => process_host_hardware(host),
          :hypervisor_hostname  => hypervisor_hostname,
          :service_tag          => normalize_blank_property(host.properties['service_tag']),
          # Attributes taken from the Cloud provider
          :availability_zone_id => cloud_host_attributes.try(:[], :availability_zone_id)
        }

        return uid, new_result
      end

      def process_host_hardware(host)
        cores_per_socket = normalize_blank_property_num(host.properties['cores_per_socket'])
        numvcpus = normalize_blank_property_num(host.properties['numvcpus'])
        logical_cpus = cores_per_socket && numvcpus ? cores_per_socket * numvcpus : 0

        {
          :memory_cpu         => normalize_blank_property(host.properties['memory_mb']),
          :disk_capacity      => normalize_blank_property(host.properties['local_gb']),
          :logical_cpus       => logical_cpus,
          :numvcpus           => numvcpus,
          :cores_per_socket   => cores_per_socket,
          :cpu_speed          => normalize_blank_property(host.properties['cpu_speed']),
          :cpu_type           => normalize_blank_property(host.properties['cpu_type']),
          :manufacturer       => normalize_blank_property(host.properties['manufacturer']),
          :model              => normalize_blank_property(host.properties['model']),
          :guest_os_full_name => normalize_blank_property(host.properties['guest_os_full_name']),
          :guest_os           => normalize_blank_property(host.properties['guest_os']),
        }
      end

      def server_address(server, key)
        # TODO(lsmola) Nova is missing information which address is primary now,
        # so just taking first. We need to figure out how to identify it if
        # there are multiple.
        server.addresses.fetch_path('ctlplane', 0, key) if server
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

      def identify_hypervisor_hostname(host, indexed_servers)
        indexed_servers.fetch_path(host.instance_uuid).try(:name)
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

      def get_clusters
        # This counts with hosts being already collected
        hosts = @data.fetch_path(:hosts)
        clusters = infer_clusters_from_hosts(hosts)

        process_collection(clusters, :clusters) { |cluster| parse_cluster(cluster) }
        set_relationship_on_hosts(hosts)
      end

      def host_type(host)
        host_type = host[:name].scan(/\((.*?)\)/).first
        host_type.first if host_type
      end

      def cluster_name_for_host(host)
        # TODO(lsmola) name and uid should also contain stack name, add this after the patch that saves resources
        # is merged. Adding Overcloud by hard now.
        host_type = host_type(host)
        "overcloud #{host_type}"
      end

      def cluster_index_for_host(host)
        # TODO(lsmola) name and uid should also contain stack name, add this after the patch that saves resources
        # is merged. Adding Overcloud by hard now.
        host_type = host_type(host)
        "overcloud__#{host_type}"
      end

      def infer_clusters_from_hosts(hosts)
        # We will create Cluster per Stack Host type. This way we can work with the same host types together
        # as a group, e.g. all Compute hosts all Object Storage hosts, etc.
        clusters = []
        hosts.each do |host|
          host_type = host_type(host)
          # skip the non-provisoned hosts
          next unless host_type

          name = cluster_name_for_host(host)
          uid = cluster_index_for_host(host)

          clusters << {:name => name, :uid => uid}
        end
        clusters.uniq
      end

      def parse_cluster(cluster)
        name = cluster[:name]
        uid = cluster[:uid]

        new_result = {
            :ems_ref => uid,
            :uid_ems => uid,
            :name    => name,
            :type    => 'EmsClusterOpenstackInfra'
        }
        return uid, new_result
      end

      def set_relationship_on_hosts(hosts)
        hosts.each do |host|
          host[:ems_cluster] = @data_index.fetch_path(:clusters, cluster_index_for_host(host))
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
