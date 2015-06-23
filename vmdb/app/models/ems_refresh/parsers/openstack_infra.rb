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
          compute_hosts = nil
          begin
            cloud_ems.with_provider_connection do |connection|
              compute_hosts = connection.hosts.select { |x| x.service_name == "compute" }
            end
          rescue StandardError => err
            $log.error "MIQ(#{self.class.name}.#{__method__}) Error Class=#{err.class.name}, Message=#{err.message}"
            $log.error err.backtrace.join("\n")
            # Just log the error and continue the refresh, we don't want error in cloud side to affect infra refresh
            next
          end

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

      def get_extra_host_attributes(host)
        return {} if host.extra.blank? || (extra_attrs = host.extra.fetch_path('edeploy_facts')).blank?
        # Convert list of tuples from Ironic extra to hash. E.g. [[a1, a2, a3, a4], [a1, a2, b3, b4], ..] converts to
        # {a1 => {a2 => {a3 => a4, b3 => b4}}}, so we get constant access to sub indexes.
        extra_attrs.each_with_object({}) { |attr, obj| ((obj[attr[0]] ||= {})[attr[1]] ||= {})[attr[2]] = attr[3] if attr.count >= 4 }
      end

      def parse_host(host, indexed_servers, _indexed_hosts_ports, indexed_resources, cloud_hosts_attributes)
        uid                 = host.uuid
        host_name           = identify_host_name(indexed_resources, host.instance_uuid, uid)
        hypervisor_hostname = identify_hypervisor_hostname(host, indexed_servers)
        ip_address          = identify_primary_ip_address(host, indexed_servers)
        hostname            = ip_address

        extra_attributes = get_extra_host_attributes(host)

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
          # Can't get this from ironic, maybe from Glance metadata, when it will be there, or image fleecing?
          :vmm_version          => normalize_blank_property(""),
          :ipaddress            => ip_address,
          :hostname             => hostname,
          :mac_address          => identify_primary_mac_address(host, indexed_servers),
          :ipmi_address         => identify_ipmi_address(host),
          :power_state          => lookup_power_state(host.power_state),
          :connection_state     => lookup_connection_state(host.power_state),
          :hardware             => process_host_hardware(host, extra_attributes),
          :hypervisor_hostname  => hypervisor_hostname,
          :service_tag          => normalize_blank_property(extra_attributes.fetch_path('system', 'product', 'serial')),
          # Attributes taken from the Cloud provider
          :availability_zone_id => cloud_host_attributes.try(:[], :availability_zone_id)
        }

        return uid, new_result
      end

      def process_host_hardware(host, extra_attributes)
        numvcpus = normalize_blank_property_num(extra_attributes.fetch_path('cpu', 'physical', 'number'))
        logical_cpus = normalize_blank_property_num(extra_attributes.fetch_path('cpu', 'logical', 'number'))
        cores_per_socket = numvcpus && logical_cpus && numvcpus > 0 ? logical_cpus / numvcpus : 0
        cpu_speed = extra_attributes.fetch_path('cpu', 'physical_0', 'frequency')
        # Get Cpu speed in Mhz
        cpu_speed = cpu_speed ? cpu_speed.to_i / 10**6 : 0

        {
          :memory_cpu         => normalize_blank_property(host.properties['memory_mb']),
          :disk_capacity      => normalize_blank_property(host.properties['local_gb']),
          :logical_cpus       => logical_cpus,
          :numvcpus           => numvcpus,
          :cores_per_socket   => cores_per_socket,
          :cpu_speed          => normalize_blank_property_num(cpu_speed),
          :cpu_type           => normalize_blank_property(extra_attributes.fetch_path('cpu', 'physical_0', 'version')),
          :manufacturer       => normalize_blank_property(extra_attributes.fetch_path('system', 'product', 'vendor')),
          :model              => normalize_blank_property(extra_attributes.fetch_path('system', 'product', 'name')),
          :number_of_nics     => normalize_blank_property_num(extra_attributes.fetch_path('network').try(:keys).try(:count)),
          :bios               => normalize_blank_property(extra_attributes.fetch_path('firmware', 'bios', 'version')),
          # Can't get these 2 from ironic, maybe from Glance metadata, when it will be there, or image fleecing?
          :guest_os_full_name => normalize_blank_property(""),
          :guest_os           => normalize_blank_property(""),
          :disks              => process_host_hardware_disks(extra_attributes),
        }
      end

      def process_host_hardware_disks(extra_attributes)
        return [] if extra_attributes.nil? || (disks = extra_attributes.fetch_path('disk')).blank?

        disks.keys.delete_if { |x| x.include?('{') || x == 'logical' }.map do |disk|
          # Logical index contains number of logical disks
          # TODO(lsmola) For now ignoring smart data, that are in format e.g. sda{cciss,1}, we need to design
          # how to represent RAID
          {
            :device_name     => disk,
            :device_type     => 'disk',
            :controller_type => 'scsi',
            :present         => true,
            :filename        => disks.fetch_path(disk, 'id') || disks.fetch_path(disk, 'scsi-id'),
            :location        => nil,
            :size            => normalize_blank_property_num(disks.fetch_path(disk, 'size')),
            :disk_type       => nil,
            :mode            => 'persistent'
          }
        end
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
