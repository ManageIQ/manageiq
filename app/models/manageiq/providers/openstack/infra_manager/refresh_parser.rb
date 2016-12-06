module ManageIQ
  module Providers
    class Openstack::InfraManager::RefreshParser < ManageIQ::Providers::InfraManager::RefreshParser
      include Vmdb::Logging

      include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
      include ManageIQ::Providers::Openstack::RefreshParserCommon::Images
      include ManageIQ::Providers::Openstack::RefreshParserCommon::Objects
      include ManageIQ::Providers::Openstack::RefreshParserCommon::OrchestrationStacks

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

        @os_handle                  = ems.openstack_handle
        @compute_service            = @connection # for consistency
        @baremetal_service          = @os_handle.detect_baremetal_service
        @identity_service           = @os_handle.identity_service
        @orchestration_service      = @os_handle.detect_orchestration_service
        @image_service              = @os_handle.detect_image_service
        @storage_service            = @os_handle.detect_storage_service
        @introspection_service      = @os_handle.detect_introspection_service

        validate_required_services
      end

      def validate_required_services
        unless @identity_service
          raise MiqException::MiqOpenstackKeystoneServiceMissing, "Required service Keystone is missing in the catalog."
        end

        unless @compute_service
          raise MiqException::MiqOpenstackNovaServiceMissing, "Required service Nova is missing in the catalog."
        end

        unless @image_service
          raise MiqException::MiqOpenstackGlanceServiceMissing, "Required service Glance is missing in the catalog."
        end

        unless @baremetal_service
          raise MiqException::MiqOpenstackIronicServiceMissing, "Required service Ironic is missing in the catalog."
        end
      end

      def ems_inv_to_hashes
        log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data" \
                     " for EMS name: [#{@ems.name}] id: [#{@ems.id}]"
        $fog_log.info("#{log_header}...")
        # The order of the below methods does matter, because there are inner dependencies of the data!

        # get_flavors # Not needed in infra
        # get_availability_zones # Not needed in infra
        # get_tenants # TODO(lsmola) should be needed, add it
        # get_quotas # Not needed in infra
        # get_key_pairs # Not needed in infra
        get_images

        get_object_store
        # get_object_store needs to run before load hosts
        load_hosts

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
          # Filtering just server resources which is important to us for getting Purpose of the node
          # (compute, controller, etc.).
          resources += all_stack_server_resources(stack).select do |x|
            %w(OS::TripleO::Server OS::Nova::Server).include?(x["resource_type"])
          end
        end
        @all_server_resources = resources
      end

      def all_stack_server_resources(stack)
        # TODO(lsmola) loading this from already obtained nested stack hierarchy will be more effective. This is one
        # extra API call. But we will need to change order of loading, so we have all resources first.
        # Nested depth 50 just for sure, although nobody should nest templates that much
        # To further speed up the query we only search for those resources we care about - those whose
        # physical_resource_id matches the id of a nova server
        server_ids = servers.map{|s| s.id}
        @orchestration_service.list_resources(:stack => stack, :nested_depth => 50, :physical_resource_id => server_ids).body['resources']
      end

      def servers
        @servers ||= @connection.handled_list(:servers)
      end

      def hosts
        @hosts ||= @baremetal_service.handled_list(:nodes)
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
            _log.error "Error Class=#{err.class.name}, Message=#{err.message}"
            $log.error err.backtrace.join("\n")
            # Just log the error and continue the refresh, we don't want error in cloud side to affect infra refresh
            next
          end

          compute_hosts.each do |compute_host|
            # We need to take correct zone id from correct provider, since the zone name can be the same
            # across providers
            availability_zone_id = cloud_ems.availability_zones.find_by(:name => compute_host.zone).try(:id)
            hosts_attributes << {:host_name => compute_host.host_name, :availability_zone_id => availability_zone_id}
          end
        end
        hosts_attributes
      end

      def load_hosts
        # Servers contains assigned IP address of hosts, there can be only
        # one nova server per host, only if the host is provisioned.
        indexed_servers = {}
        servers.each { |s| indexed_servers[s.id] = s }

        # Indexed Heat resources, we are interested only in OS::Nova::Server/OS::TripleO::Server
        indexed_resources = {}
        all_server_resources.each { |p| indexed_resources[p['physical_resource_id']] = p }

        process_collection(hosts, :hosts) do  |host|
          parse_host(host, indexed_servers, indexed_resources, cloud_ems_hosts_attributes)
        end
      end

      def get_introspection_details(host)
        return {} unless @introspection_service
        begin
          @introspection_service.get_introspection_details(host.uuid).body
        rescue
          # introspection data not available
          {}
        end
      end

      def get_extra_attributes(introspection_details)
        return {} if introspection_details.blank? || introspection_details["extra"].nil?
        introspection_details["extra"]
      end

      def parse_host(host, indexed_servers, indexed_resources, cloud_hosts_attributes)
        uid                 = host.uuid
        host_name           = identify_host_name(indexed_resources, host.instance_uuid, uid)
        hypervisor_hostname = identify_hypervisor_hostname(host, indexed_servers)
        ip_address          = identify_primary_ip_address(host, indexed_servers)
        hostname            = ip_address

        introspection_details = get_introspection_details(host)
        extra_attributes = get_extra_attributes(introspection_details)

        # Get the cloud_host_attributes by hypervisor hostname, only compute hosts can get this
        cloud_host_attributes = cloud_hosts_attributes.select do |x|
          hypervisor_hostname && x[:host_name].include?(hypervisor_hostname.downcase)
        end
        cloud_host_attributes = cloud_host_attributes.first if cloud_host_attributes

        new_result = {
          :name                 => host_name,
          :type                 => 'ManageIQ::Providers::Openstack::InfraManager::Host',
          :uid_ems              => uid,
          :ems_ref              => uid,
          :ems_ref_obj          => host.instance_uuid,
          :operating_system     => {:product_name => 'linux'},
          :vmm_vendor           => 'redhat',
          :vmm_product          => identify_product(indexed_resources, host.instance_uuid),
          # Can't get this from ironic, maybe from Glance metadata, when it will be there, or image fleecing?
          :vmm_version          => nil,
          :ipaddress            => ip_address,
          :hostname             => hostname,
          :mac_address          => identify_primary_mac_address(host, indexed_servers),
          :ipmi_address         => identify_ipmi_address(host),
          :power_state          => lookup_power_state(host.power_state),
          :connection_state     => lookup_connection_state(host.power_state),
          :maintenance          => host.maintenance,
          :maintenance_reason   => host.maintenance_reason,
          :hardware             => process_host_hardware(host, introspection_details),
          :hypervisor_hostname  => hypervisor_hostname,
          :service_tag          => extra_attributes.fetch_path('system', 'product', 'serial'),
          # TODO(lsmola) need to add column for connection to SecurityGroup
          # :security_group_id  => security_group_id
          # Attributes taken from the Cloud provider
          :availability_zone_id => cloud_host_attributes.try(:[], :availability_zone_id)
        }

        return uid, new_result
      end

      def process_host_hardware(host, introspection_details)
        extra_attributes     = get_extra_attributes(introspection_details)
        cpu_sockets          = extra_attributes.fetch_path('cpu', 'physical', 'number').to_i
        cpu_total_cores      = extra_attributes.fetch_path('cpu', 'logical', 'number').to_i
        cpu_cores_per_socket = cpu_sockets > 0 ? cpu_total_cores / cpu_sockets : 0
        cpu_speed            = introspection_details.fetch_path('inventory', 'cpu', 'frequency').to_i

        {
          :memory_mb            => host.properties['memory_mb'],
          :disk_capacity        => host.properties['local_gb'],
          :cpu_total_cores      => cpu_total_cores,
          :cpu_sockets          => cpu_sockets,
          :cpu_cores_per_socket => cpu_cores_per_socket,
          :cpu_speed            => cpu_speed,
          :cpu_type             => extra_attributes.fetch_path('cpu', 'physical_0', 'version'),
          :manufacturer         => extra_attributes.fetch_path('system', 'product', 'vendor'),
          :model                => extra_attributes.fetch_path('system', 'product', 'name'),
          :number_of_nics       => extra_attributes.fetch_path('network').try(:keys).try(:count).to_i,
          :bios                 => extra_attributes.fetch_path('firmware', 'bios', 'version'),
          # Can't get these 2 from ironic, maybe from Glance metadata, when it will be there, or image fleecing?
          :guest_os_full_name   => nil,
          :guest_os             => nil,
          :disks                => process_host_hardware_disks(extra_attributes),
          :introspected         => !introspection_details.blank?,
          # fog-openstack baremetal service defaults to Ironic API v1.1.
          # In version 1.1 "available" is shown as null in JSON. It is correctly
          # shown as "available" starting with version 1.2.
          # This may need to change once this issue is addressed:
          # https://github.com/fog/fog-openstack/issues/197
          :provision_state      => host.provision_state.nil? ? "available" : host.provision_state,
        }
      end

      def process_host_hardware_disks(extra_attributes)
        return [] if extra_attributes.nil? || (disks = extra_attributes.fetch_path('disk')).blank?

        disks.keys.delete_if { |x| x.include?('{') || x == 'logical' }.map do |disk|
          # Logical index contains number of logical disks
          # TODO(lsmola) For now ignoring smart data, that are in format e.g. sda{cciss,1}, we need to design
          # how to represent RAID
          # Convert the disk size from GB to B
          disk_size = disks.fetch_path(disk, 'size').to_i * 1_024**3
          {
            :device_name     => disk,
            :device_type     => 'disk',
            :controller_type => 'scsi',
            :present         => true,
            :filename        => disks.fetch_path(disk, 'id') || disks.fetch_path(disk, 'scsi-id'),
            :location        => nil,
            :size            => disk_size,
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
        clusters, cluster_host_mapping = get_clusters_and_host_mapping
        process_collection(clusters, :clusters) { |cluster| parse_cluster(cluster) }

        set_relationship_on_hosts(hosts, cluster_host_mapping)
      end

      def get_clusters_and_host_mapping
        clusters = []
        cluster_host_mapping = {}
        orchestration_stacks = @data_index.fetch_path(:orchestration_stacks)
        orchestration_stacks.each_value do |stack|
          uid = stack.fetch_path(:parent, :ems_ref)
          next unless uid

          nova_server = stack[:resources].detect do |r|
            %w(OS::TripleO::Server OS::Nova::Server).include?(r[:resource_category])
          end
          next unless nova_server

          cluster_host_mapping[nova_server[:physical_resource]] = uid
          clusters << {:name => stack[:parent][:name], :uid => uid}
        end if orchestration_stacks
        return clusters.uniq, cluster_host_mapping
      end

      def parse_cluster(cluster)
        name = cluster[:name]
        uid = cluster[:uid]

        new_result = {
          :ems_ref => uid,
          :uid_ems => uid,
          :name    => name,
          :type    => 'ManageIQ::Providers::Openstack::InfraManager::EmsCluster'
        }
        return uid, new_result
      end

      def set_relationship_on_hosts(hosts, cluster_host_mapping)
        hosts.each do |host|
          host[:ems_cluster] = @data_index.fetch_path(:clusters, cluster_host_mapping[host[:ems_ref_obj]])
        end
      end

      def get_object_content(obj)
        obj.body
      end

      def self.miq_template_type
        "ManageIQ::Providers::Openstack::InfraManager::Template"
      end

      #
      # Helper methods
      #


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
