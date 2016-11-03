# TODO: Separate collection from parsing (perhaps collecting in parallel a la RHEVM)

module ManageIQ::Providers
  class Openstack::CloudManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
    include Vmdb::Logging
    include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
    include ManageIQ::Providers::Openstack::RefreshParserCommon::Images
    include ManageIQ::Providers::Openstack::RefreshParserCommon::Objects
    include ManageIQ::Providers::Openstack::RefreshParserCommon::OrchestrationStacks

    def self.ems_inv_to_hashes(ems, options = nil)
      new(ems, options).ems_inv_to_hashes
    end

    def initialize(ems, options = nil)
      @ems               = ems
      @connection        = ems.connect
      @options           = options || {}
      @data              = {}
      @data_index        = {}
      @known_flavors     = Set.new
      @resource_to_stack = {}

      @os_handle                  = ems.openstack_handle
      @compute_service            = @connection # for consistency
      # TODO(lsmola) delete network_service once everything is moved under NetworkManager
      @network_service            = @os_handle.detect_network_service
      @image_service              = @os_handle.detect_image_service
      @volume_service             = @os_handle.detect_volume_service
      @storage_service            = @os_handle.detect_storage_service
      @identity_service           = @os_handle.identity_service
      @orchestration_service      = @os_handle.detect_orchestration_service

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
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

      $fog_log.info("#{log_header}...")
      # The order of the below methods does matter, because there are inner dependencies of the data!
      get_flavors
      get_availability_zones
      get_tenants
      get_quotas
      get_key_pairs
      load_orchestration_stacks
      # get_hosts
      get_images
      get_servers
      get_volumes
      get_snapshots
      get_object_store
      get_cloud_services

      $fog_log.info("#{log_header}...Complete")

      link_vm_genealogy
      link_storage_associations
      filter_unused_disabled_flavors

      @data
    end

    private

    def child_manager_fetch_path(collection, ems_ref)
      @child_manager_data ||= {}
      return @child_manager_data.fetch_path(collection, ems_ref) if @child_manager_data.has_key_path?(collection, ems_ref)
      @child_manager_data.store_path(collection, ems_ref, @ems.public_send(collection).try(:where, :ems_ref => ems_ref).try(:first))
    end

    def servers
      @servers ||= @connection.handled_list(:servers)
    end

    def availability_zones_compute
      @availability_zones_compute ||= safe_list { @connection.availability_zones.summary }
    end

    def availability_zones_volume
      @availability_zones_volume ||= safe_list { @volume_service.availability_zones.summary }
    end

    def availability_zones
      @availability_zones ||= (availability_zones_compute + availability_zones_volume).uniq(&:zoneName)
    end

    def volumes
      # TODO: support volumes through :nova as well?
      return [] unless @volume_service.name == :cinder
      @volumes ||= @volume_service.handled_list(:volumes)
    end

    def get_flavors
      flavors = @connection.handled_list(:flavors)
      process_collection(flavors, :flavors) { |flavor| parse_flavor(flavor) }
    end

    def get_private_flavor(id)
      private_flavor = safe_get { @connection.flavors.get(id) }
      process_collection([private_flavor], :flavors) { |flavor| parse_flavor(flavor) } if private_flavor
    end

    def get_availability_zones
      azs = availability_zones
      azs << nil # force the null availability zone for openstack
      process_collection(azs, :availability_zones) { |az| parse_availability_zone(az) }
    end

    def get_tenants
      @tenants = @os_handle.accessible_tenants.select { |t| t.name != "services" }
      process_collection(@tenants, :cloud_tenants) { |tenant| parse_tenant(tenant) }
    end

    def get_quotas
      quotas = safe_list { @compute_service.quotas_for_accessible_tenants }
      quotas.concat(safe_list { @volume_service.quotas_for_accessible_tenants })  if @volume_service.name == :cinder
      # TODO(lsmola) can this somehow be moved under NetworkManager
      quotas.concat(safe_list { @network_service.quotas_for_accessible_tenants }) if @network_service.name == :neutron

      process_collection(flatten_quotas(quotas), :cloud_resource_quotas) { |quota| parse_quota(quota) }
    end

    def get_key_pairs
      kps = @connection.handled_list(:key_pairs)
      process_collection(kps, :key_pairs) { |kp| parse_key_pair(kp) }
    end

    def get_volumes
      process_collection(volumes, :cloud_volumes) { |volume| parse_volume(volume) }
    end

    def get_snapshots
      return unless @volume_service.name == :cinder
      process_collection(@volume_service.handled_list(:list_snapshots_detailed,
                                                      :__request_body_index => "snapshots"),
                         :cloud_volume_snapshots) { |snap| parse_snapshot(snap) }
    end

    def get_servers
      openstack_infra_hosts = @ems.provider.try(:infra_ems).try(:hosts)
      process_collection(servers, :vms) { |server| parse_server(server, openstack_infra_hosts) }
    end

    def link_vm_genealogy
      @data[:vms].each do |vm|
        parent_vm_uid = vm.delete(:parent_vm_uid)
        parent_vm = @data_index.fetch_path(:vms, parent_vm_uid)
        vm[:parent_vm] = parent_vm unless parent_vm.nil?
      end
    end

    def link_storage_associations
      @data[:cloud_volumes].each do |cv|
        #
        # Associations between volumes and the snapshots on which
        # they are based, if any.
        #
        base_snapshot_uid = cv.delete(:snapshot_uid)
        base_snapshot = @data_index.fetch_path(:cloud_volume_snapshots, base_snapshot_uid)
        cv[:base_snapshot] = base_snapshot unless base_snapshot.nil?
      end if @data[:cloud_volumes]
    end

    def parse_flavor(flavor)
      uid = flavor.id

      new_result = {
        :type                 => "ManageIQ::Providers::Openstack::CloudManager::Flavor",
        :ems_ref              => uid,
        :name                 => flavor.name,
        :enabled              => !flavor.disabled,
        :cpus                 => flavor.vcpus,
        :memory               => flavor.ram.megabytes,
        :root_disk_size       => flavor.disk.to_i.gigabytes,
        :swap_disk_size       => flavor.swap.to_i.megabytes,
        :ephemeral_disk_size  => flavor.ephemeral.nil? ? nil : flavor.ephemeral.to_i.gigabytes,
        :ephemeral_disk_count => if flavor.ephemeral.nil?
                                   nil
                                 elsif flavor.ephemeral.to_i > 0
                                   1
                                 else
                                   0
                                 end
      }

      return uid, new_result
    end

    def parse_availability_zone(az)
      if az.nil?
        uid        = "null_az"
        new_result = {
          :type    => "ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull",
          :ems_ref => uid
        }
      else
        name = uid = az.zoneName
        new_result = {
          :type    => "ManageIQ::Providers::Openstack::CloudManager::AvailabilityZone",
          :ems_ref => uid,
          :name    => name
        }
      end
      return uid, new_result
    end

    def parse_tenant(tenant)
      uid = tenant.id

      new_result = {
        :type        => "ManageIQ::Providers::Openstack::CloudManager::CloudTenant",
        :name        => tenant.name,
        :description => tenant.description,
        :enabled     => tenant.enabled,
        :ems_ref     => uid,
      }

      return uid, new_result
    end

    def flatten_quotas(quotas)
      quotas.collect { |q| flatten_quota(q) }.flatten
    end

    # Each call to "get_quota" returns a hash of the form:
    #   {"id" => "ems_ref", "quota_key_1" => "value", "quota_key_2" => "value"}
    # we want hashes that look more like:
    #   {:cloud_tenant => 123, :service_name => "compute", :name => "quota_key_1", :value => "value"},
    #   {:cloud_tenant => 123, :service_name => "compute", :name => "quota_key_2", :value => "value"}
    # So, one input quota record will be parsed into an array of output quota records.
    def flatten_quota(quota)
      # The array of hashes returned from this block is the same as what would
      # be produced by parse_quota ... so, parse_quota just returns the same
      # hash with a compound key.
      quota.except("id", "tenant_id", "service_name").collect do |key, value|
        begin
          value = value.to_i
        rescue
          # TODO: determine a decent "error" value here
          #  -1 is a valid value from the service and means "unlimited"
          value = 0
        end
        {
          :cloud_tenant => @data_index.fetch_path(:cloud_tenants, quota["tenant_id"]),
          :service_name => quota["service_name"],
          :ems_ref      => quota["id"],
          :name         => key,
          :value        => value,
          :type         => "ManageIQ::Providers::Openstack::CloudManager::CloudResourceQuota",
        }
      end
    end

    def parse_quota(quota)
      uid = [quota["ems_ref"], quota["name"]]
      return uid, quota
    end

    def self.key_pair_type
      'ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair'
    end

    def self.miq_template_type
      "ManageIQ::Providers::Openstack::CloudManager::Template"
    end

    def parse_volume(volume)
      log_header = "MIQ(#{self.class.name}.#{__method__})"

      uid = volume.id
      new_result = {
        :ems_ref           => uid,
        :type              => "ManageIQ::Providers::Openstack::CloudManager::CloudVolume",
        :name              => volume_name(volume),
        :status            => volume.status,
        :bootable          => volume.attributes['bootable'],
        :creation_time     => volume.created_at,
        :description       => volume_description(volume),
        :volume_type       => volume.volume_type,
        :snapshot_uid      => volume.snapshot_id,
        :size              => volume.size.to_i.gigabytes,
        :tenant            => @data_index.fetch_path(:cloud_tenants, volume.tenant_id),
        :availability_zone => @data_index.fetch_path(:availability_zones, volume.availability_zone || "null_az"),
      }

      volume.attachments.each do |a|
        if a['device'].blank?
          $fog_log.warn "#{log_header}: Volume: #{uid}, is missing a mountpoint, skipping the volume processing"
          $fog_log.warn "#{log_header}:   EMS: #{@ems.name}, Instance: #{a['server_id']}"
          next
        end

        dev = File.basename(a['device'])
        disks = @data_index.fetch_path(:vms, a['server_id'], :hardware, :disks)

        unless disks
          $fog_log.warn "#{log_header}: Volume: #{uid}, attached to instance not visible in the scope of this EMS"
          $fog_log.warn "#{log_header}:   EMS: #{@ems.name}, Instance: #{a['server_id']}"
          next
        end

        if (disk = disks.detect { |d| d[:location] == dev })
          disk[:size] = new_result[:size]
        else
          disk = add_instance_disk(disks, new_result[:size], dev, "OpenStack Volume")
        end

        if disk
          disk[:backing]      = new_result
          disk[:backing_type] = 'CloudVolume'
        end
      end

      return uid, new_result
    end

    def volume_name(volume)
      # Cinder v1
      return volume.display_name if volume.respond_to?(:display_name)
      # Cinder v2
      return volume.name
    end

    def volume_description(volume)
      # Cinder v1
      return volume.display_description if volume.respond_to?(:display_description)
      # Cinder v2
      return volume.description
    end

    def parse_snapshot(snap)
      uid = snap['id']
      new_result = {
        :ems_ref       => uid,
        :type          => "ManageIQ::Providers::Openstack::CloudManager::CloudVolumeSnapshot",
        # Supporting both Cinder v1 and Cinder v2
        :name          => snap['display_name'] || snap['name'],
        :status        => snap['status'],
        :creation_time => snap['created_at'],
        # Supporting both Cinder v1 and Cinder v2
        :description   => snap['display_description'] || snap['description'],
        :size          => snap['size'].to_i.gigabytes,
        :tenant        => @data_index.fetch_path(:cloud_tenants, snap['os-extended-snapshot-attributes:project_id']),
        :volume        => @data_index.fetch_path(:cloud_volumes, snap['volume_id'])
      }
      return uid, new_result
    end

    def parse_server(server, parent_hosts = nil)
      uid = server.id

      raw_power_state = server.state || "UNKNOWN"

      flavor_uid = server.flavor["id"]
      @known_flavors << flavor_uid
      flavor = @data_index.fetch_path(:flavors, flavor_uid)
      if flavor.nil?
        get_private_flavor(flavor_uid)
        flavor = @data_index.fetch_path(:flavors, flavor_uid)
      end

      # TODO(lsmola) keeping for backwards compatibility, replaced with new networking models using network_ports
      # for connections, delete when not needed.
      private_network = {:ipaddress => server.private_ip_address}.delete_nils
      public_network  = {:ipaddress => server.public_ip_address}.delete_nils
      if parent_hosts
        # Find associated host from OpenstackInfra
        filtered_hosts = parent_hosts.select do |x|
          x.hypervisor_hostname && server.os_ext_srv_attr_host && server.os_ext_srv_attr_host.include?(x.hypervisor_hostname.downcase)
        end
        parent_host = filtered_hosts.first
        parent_cluster = parent_host.try(:ems_cluster)
      else
        parent_host = nil
        parent_cluster = nil
      end

      parent_image_uid = server.image["id"]

      new_result = {
        :type                => "ManageIQ::Providers::Openstack::CloudManager::Vm",
        :uid_ems             => uid,
        :ems_ref             => uid,
        :name                => server.name,
        :vendor              => "openstack",
        :raw_power_state     => raw_power_state,
        :connection_state    => "connected",

        :hardware            => {
          :cpu_sockets          => flavor[:cpus],
          :cpu_cores_per_socket => 1,
          :cpu_total_cores      => flavor[:cpus],
          :cpu_speed            => parent_host.try(:hardware).try(:cpu_speed),
          :memory_mb            => flavor[:memory] / 1.megabyte,
          :disk_capacity        => flavor[:root_disk_size] + flavor[:ephemeral_disk_size] + flavor[:swap_disk_size],
          :disks                => [], # Filled in later conditionally on flavor
          # TODO(lsmola) keeping for backwards compatibility, replaced with new networking models using network_ports
          # for connections, delete when not needed.
          :networks             => [], # Filled in later conditionally on what's available
        },
        :host                => parent_host,
        :ems_cluster         => parent_cluster,
        :flavor              => flavor,
        :availability_zone   => @data_index.fetch_path(
          :availability_zones, server.availability_zone.blank? ? "null_az" : server.availability_zone
        ),
        :key_pairs           => [@data_index.fetch_path(:key_pairs, server.key_name)].compact,
        # TODO(lsmola) moving this under has_many :security_groups, :through => :network_port will require changing
        # saving code and refresh of all providers
        :security_groups     => server.security_groups.collect { |sg| child_manager_fetch_path(:security_groups, sg.id) }.compact,
        :cloud_tenant        => @data_index.fetch_path(:cloud_tenants, server.tenant_id),
        :orchestration_stack => @data_index.fetch_path(:orchestration_stacks, @resource_to_stack[uid])
      }
      # TODO(lsmola) keeping for backwards compatibility, replaced with new networking models using network_ports
      # for connections, delete when not needed.
      new_result[:hardware][:networks] << private_network.merge(:description => "private") unless private_network.blank?
      new_result[:hardware][:networks] << public_network.merge(:description => "public")   unless public_network.blank?

      new_result[:parent_vm_uid] = parent_image_uid unless parent_image_uid.nil?

      disks = new_result[:hardware][:disks]
      dev = "vda"

      if (sz = flavor[:root_disk_size]) == 0
        sz = 1.gigabytes
      end
      add_instance_disk(disks, sz, dev.dup,       "Root disk")
      sz = flavor[:ephemeral_disk_size]
      add_instance_disk(disks, sz, dev.succ!.dup, "Ephemeral disk") unless sz.zero?
      sz = flavor[:swap_disk_size]
      add_instance_disk(disks, sz, dev.succ!.dup, "Swap disk")      unless sz.zero?

      return uid, new_result
    end

    def clean_up_extra_flavor_keys
      @data[:flavors].each do |f|
        f.delete(:ephemeral_disk)
        f.delete(:swap_disk)
      end
    end

    def add_instance_disk(disks, size, location, name)
      super(disks, size, location, name, "openstack")
    end

    def get_cloud_services
      # TODO(pblaho): repeat for each posible service (compute, identity, ...)
      source = 'compute'
      services = @compute_service.handled_list(:services)
      process_collection(services, :cloud_services) { |service| parse_cloud_service(service, source) }
    end

    def parse_cloud_service(service, source)
      uid = service.id

      infra_ems = @ems.provider && @ems.provider.try(:infra_ems)
      hosts = infra_ems.try(:hosts)

      host = hosts.try(:find) { |h| h.hypervisor_hostname == service.host.split('.').first }
      system_services = host.try(:system_services)
      system_service = system_services.try(:find) { |ss| ss.name =~ /#{service.binary}/ }
      availability_zone = @ems.availability_zones.find { |zone| zone.ems_ref == service.zone }

      new_result = {
        :ems_ref                    => uid,
        :source                     => source,
        :executable_name            => service.binary,
        :hostname                   => service.host,
        :status                     => service.state,
        :scheduling_disabled        => service.status == 'disabled' ? true : false,
        :scheduling_disabled_reason => service.disabled_reason,
        :host                       => host,
        :system_service             => system_service,
        :availability_zone          => availability_zone,
      }

      return uid, new_result
    end
  end
end
