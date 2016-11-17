module ManageIQ::Providers::Microsoft
  class InfraManager::RefreshParser < EmsRefresh::Parsers::Infra
    INVENTORY_SCRIPT           = File.join(File.dirname(__FILE__), 'ps_scripts/get_inventory.ps1')
    DRIVE_LETTER               = /\A[a-z][:]/i
    UNSUPPORTED_HOST_PLATFORMS = %w(vmwareesx)

    def self.ems_inv_to_hashes(ems, options = nil)
      new(ems, options).ems_inv_to_hashes
    end

    def initialize(ems, _options = nil)
      @ems                = ems
      @connection         = ems.connect
      @data               = {}
      @data_index         = {}
      @host_hash_by_name  = {}
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"
      $scvmm_log.info("#{log_header}...")
      @inventory = ManageIQ::Providers::Microsoft::InfraManager.execute_powershell(@connection, INVENTORY_SCRIPT).first
      if @inventory.empty?
        $scvmm_log.warn("#{log_header}...Empty inventory set returned from SCVMM.")
        return
      end

      get_ems
      get_datastores
      get_hosts
      get_clusters
      get_vms
      get_images
      create_relationship_tree
      $scvmm_log.info("#{log_header}...Complete")
      @data
    end

    private

    def get_ems
      return if @inventory[:ems].nil?

      @ems.api_version = normalize_blank_property(@inventory[:ems][:Props][:ServerInterfaceVersion])
      @ems.uid_ems     = normalize_blank_property(@inventory[:ems][:Props][:ManagedComputer][0][:Props][:ID])
    end

    def get_datastores
      datastores = @inventory[:datastores]
      process_collection(datastores, :storages) { |ds| parse_datastore(ds) }
    end

    def get_hosts
      hosts = @inventory[:hosts]
      process_collection(hosts, :hosts) { |host| parse_host(host) }
    end

    def get_clusters
      clusters = @inventory[:clusters]
      process_collection(clusters, :clusters) { |cluster| parse_cluster(cluster) }
    end

    def get_vms
      vms = @inventory[:vms]
      process_collection(vms, :vms) { |vm| parse_vm(vm) }
    end

    def get_images
      images = @inventory[:images]
      process_collection(images, :vms) { |image| parse_image(image) }
    end

    def parse_datastore(datastore)
      volume = datastore[:Props]
      uid = volume[:ID]

      new_result = {
        :ems_ref                     => uid,
        :name                        => File.path_to_uri(volume[:Name], volume[:VMHost][:ToString]),
        :store_type                  => volume[:FileSystem],
        :total_space                 => volume[:Capacity],
        :free_space                  => volume[:FreeSpace],
        :multiplehostaccess          => true,
        :thin_provisioning_supported => true,
        :location                    => uid,   # HACK: get around save_inventory issues by reusing uid.
      }

      return uid, new_result
    end

    def parse_cluster(cluster)
      p     = cluster[:Properties][:Props]
      uid   = p[:ID]
      nodes = p[:Nodes]
      name  = p[:ClusterName]

      new_result = {
        :ems_ref => uid,
        :uid_ems => uid,
        :name    => name,
      }
      set_relationship_on_hosts(new_result, nodes)

      # ignore clusters that are left without any hosts after hosts were filtered for UNSUPPORTED_HOST_PLATFORMS
      return uid, new_result if @data[:hosts].any? { |host| host[:ems_cluster] == new_result }
    end

    def parse_host(host)
      p          = host[:Properties][:Props]
      uid        = p[:ID]
      host_name  = p[:Name]

      host_platform = p[:VirtualizationPlatform][:ToString].downcase
      if UNSUPPORTED_HOST_PLATFORMS.include? host_platform
        $scvmm_log.warn("#{host_platform} servers are not supported, skipping #{host_name}")
        return
      end

      new_result = {
        :name             => host_name,
        :type             => 'ManageIQ::Providers::Microsoft::InfraManager::Host',
        :uid_ems          => uid,
        :ems_ref          => uid,
        :hostname         => host_name,
        :ipaddress        => identify_primary_ip(host[:NetworkAdapters], host_name),
        :vmm_vendor       => 'microsoft',
        :vmm_version      => p[:HyperVVersion],
        :vmm_product      => p[:VirtualizationPlatform][:ToString],
        :power_state      => lookup_power_state(p[:HyperVState][:ToString]),
        :connection_state => lookup_connected_state(p[:CommunicationState][:ToString]),

        :operating_system => process_os(p),
        :hardware         => process_host_hardware(host),
        :storages         => process_host_storages(p),
        :switches         => process_virtual_switches(host)
      }

      @data_index.store_path(:hosts_by_host_name, host_name, new_result)
      @data_index.store_path(:host_uid_to_datastore_mount_point_mapping, uid, map_mount_point_to_datastore(p))

      return uid, new_result
    end

    def process_virtual_switches(host)
      result = []

      virtual_switches = host[:VirtualSwitch]
      return result if virtual_switches.nil?

      virtual_switches.each do |vs_hash|
        v_switch = vs_hash[:Props]

        switch = {
          :uid_ems => v_switch[:ID],
          :name    => v_switch[:Name],
          :lans    => process_logical_networks(v_switch[:LogicalNetworks])
        }
        result << switch
        v_switch[:VMHostNetworkAdapters].collect { |adapter| set_switch_on_pnic(adapter[:Props], switch) }
      end
      result
    end

    def process_logical_networks(logical_networks)
      result = []

      logical_networks.each do |ln|
        next if ln.nil?

        result << {
          :name    => ln[:Props][:Name],
          :uid_ems => ln[:Props][:ID],
        }
      end
      result
    end

    def set_switch_on_pnic(pnic, switch)
      pnic_obj = @data_index.fetch_path(:physical_nic, pnic[:ID])
      pnic_obj[:switch] = switch
    end

    def parse_vm(vm)
      p                = vm[:Properties][:Props]
      uid              = p[:ID]
      connection_state = p[:ServerConnection][:Props][:IsConnected].to_s
      host             = @data_index.fetch_path(:hosts_by_host_name, p[:HostName])

      new_result = {
        :name             => p[:Name],
        :ems_ref          => uid,
        :uid_ems          => uid,
        :type             => 'ManageIQ::Providers::Microsoft::InfraManager::Vm',
        :vendor           => "microsoft",
        :raw_power_state  => p[:VirtualMachineState][:ToString],
        :operating_system => process_vm_os(p[:OperatingSystem]),
        :connection_state => lookup_connected_state(connection_state),
        :tools_status     => process_tools_status(p),
        :host             => host,
        :ems_cluster      => host && normalize_blank_property(host[:ems_cluster]),
        :hardware         => process_vm_hardware(vm),
        :snapshots        => process_snapshots(p),
        :storage          => process_vm_storage(p[:VMCPath], host),
        :storages         => process_vm_storages(p),
      }
      new_result[:location] = p[:VMCPath].nil? ? "unknown" : p[:VMCPath].sub(DRIVE_LETTER, "").strip
      return uid, new_result
    end

    def parse_image(image)
      p               = image[:Properties][:Props]
      uid             = p[:ID]

      new_result = {
        :type             => "ManageIQ::Providers::Microsoft::InfraManager::Template",
        :uid_ems          => uid,
        :ems_ref          => uid,
        :vendor           => "microsoft",
        :operating_system => process_vm_os(p[:OperatingSystem]),
        :name             => p[:Name],
        :raw_power_state  => "never",
        :template         => true,
        :storages         => process_vm_storages(p),
        :hardware         => {
          :cpu_total_cores    => p[:CPUCount],
          :memory_mb          => normalize_blank_property_num(p[:Memory]),
          :cpu_type           => p[:CPUType].blank? ? nil : p[:CPUType][:ToString],
          :disks              => process_disks(p),
          :guest_devices      => process_vm_guest_devices(image),
          :guest_os           => p[:OperatingSystem][:Props][:Name],
          :guest_os_full_name => p[:OperatingSystem][:Props][:Name],
        },
      }

      return uid, new_result
    end

    def process_host_hardware(host)
      p                = host[:Properties][:Props]
      cpu_family       = normalize_blank_property(p[:ProcessorFamily])
      cpu_manufacturer = normalize_blank_property(p[:ProcessorManufacturer])
      cpu_model        = normalize_blank_property(p[:ProcessorModel])

      {
        :cpu_type             => "#{cpu_manufacturer} #{cpu_model} #{cpu_family}",
        :manufacturer         => cpu_manufacturer,
        :model                => cpu_model,
        :cpu_speed            => normalize_blank_property_num(p[:ProcessorSpeed]),
        :memory_mb            => normalize_blank_property(p[:TotalMemory]) / 1.megabyte,
        :cpu_sockets          => normalize_blank_property_num(p[:PhysicalCPUCount]),
        :cpu_total_cores      => normalize_blank_property_num(p[:LogicalProcessorCount]),
        :cpu_cores_per_socket => normalize_blank_property_num(p[:CoresPerCPU]),
        :guest_devices        => process_host_guest_devices(host),
      }
    end

    def process_host_storages(properties)
      properties[:DiskVolumes].collect do |dv|
        @data_index.fetch_path(:storages, dv[:Props][:ID])
      end.compact
    end

    def map_mount_point_to_datastore(properties)
      log_header = "MIQ(#{self.class.name}.#{__method__})"
      properties[:DiskVolumes].each.with_object({}) do |dv, h|
        mount_point    = dv[:Props][:Name].match(DRIVE_LETTER).to_s
        $scvmm_log.debug("#{log_header} Drive #{dv[:Props][:Name]} missing drive letter") if mount_point.blank?
        next if mount_point.blank?
        storage        = @data_index.fetch_path(:storages, dv[:Props][:ID])
        h[mount_point] = storage
      end
    end

    def process_host_guest_devices(host)
      result           = []
      network_adapters = host[:NetworkAdapters]
      network_adapters.each do |pnic|
        pnic_p = pnic[:Props]
        new_result = build_network_adapter_hash(pnic_p)
        result << new_result
      end

      dvds = host[:Properties][:Props][:DVDDriveList]
      dvds.each do |dvd|
        result << build_dvd_hash(dvd)
      end

      result
    end

    def build_network_adapter_hash(pnic_p)
      p_nic_obj = {
        :uid_ems         => pnic_p[:ID],
        :device_name     => pnic_p[:ConnectionName],
        :device_type     => 'ethernet',
        :model           => pnic_p[:Name],
        :location        => pnic_p[:BDFLocationInformation],
        :present         => 'true',
        :start_connected => 'true',
        :controller_type => 'ethernet',
        :address         => pnic_p[:MacAddress],
      }
      @data_index.store_path(:physical_nic, pnic_p[:ID], p_nic_obj)
    end

    def build_dvd_hash(dvd)
      {
        :device_type     => 'cdrom', # TODO: add DVD to model
        :present         => true,
        :controller_type => 'IDE',
        :mode            => 'persistent',
        :filename        => dvd,
      }
    end

    def process_vm_hardware(vm)
      p    = vm[:Properties][:Props]
      cpus = p[:CPUCount]

      {
        :cpu_sockets          => cpus,
        :cpu_cores_per_socket => 1,
        :cpu_total_cores      => cpus,
        :guest_os             => p[:OperatingSystem][:Props][:Name],
        :guest_os_full_name   => p[:OperatingSystem][:Props][:Name],
        :memory_mb            => normalize_blank_property_num(p[:Memory]),
        :cpu_type             => normalize_blank_property_str(p[:CPUType]),
        :disks                => process_disks(p),
        :networks             => process_hostname_and_ip(vm),
        :guest_devices        => process_vm_guest_devices(vm),
        :bios                 => p[:BiosGuid]
      }
    end

    def process_snapshots(p)
      result = []

      if p[:VMCheckpoints].nil?
        $scvmm_log.info("No snapshot information available for #{p[:Name]}")
        return result
      end

      p[:VMCheckpoints].each do |snapshot_hash|
        s = snapshot_hash[:Props]
        new_result = {
          :uid_ems     => s[:CheckpointID],
          :uid         => s[:CheckpointID],
          :ems_ref     => s[:CheckpointID],
          :parent_uid  => s[:ParentCheckpointID],
          :name        => s[:Name],
          :description => s[:description],
          :create_time => s[:AddedTime],
          :current     => s[:CheckpointID] == p[:LastRestoredCheckpointID]
        }
        result << new_result
      end

      result
    end

    def process_hostname_and_ip(vm)
      [
        {
          :hostname  => process_computer_name(vm[:Properties][:Props][:ComputerName]),
          :ipaddress => vm[:Networks]
        }
      ]
    end

    def process_computer_name(computername)
      return if computername.nil?
      log_header = "MIQ(#{self.class.name}.#{__method__})"

      if computername.start_with?("getaddrinfo failed_")
        $scvmm_log.warn("#{log_header} Invalid hostname value returned from SCVMM: #{computername}")
        "Unavailable"
      else
        computername
      end
    end

    def process_disks(vm)
      return if vm[:VirtualHardDisks].nil?

      vm[:VirtualHardDisks].collect do |disk_hash|
        disk = disk_hash[:Props]
        {
          :device_name     => disk[:Name],
          :size            => disk[:MaximumSize],
          :size_on_disk    => disk[:Size],
          :disk_type       => lookup_disk_type(disk),
          :device_type     => "disk",
          :present         => true,
          :filename        => disk[:SharePath],
          :location        => disk[:Location],
          :mode            => 'persistent',
          :controller_type => 'IDE',
        }
      end
    end

    def process_vm_guest_devices(vm)
      dvds = vm[:Properties][:Props][:VirtualDVDDrives]
      return [] if dvds.blank?

      dvdprops   = dvds[0][:Props]
      connection = dvdprops[:Connection]
      devices    = []

      devices << case connection
                 when "HostDrive" then process_vm_physical_dvd_drive(dvdprops)
                 when "ISOImage"  then process_iso_image(vm)
                 end

      devices.flatten.compact
    end

    def process_vm_physical_dvd_drive(dvd)
      uid       = dvd[:ID]
      name      = dvd[:Name]
      hostdrive = dvd[:HostDrive]

      new_result = {
        :device_type     => 'cdrom',  # TODO: add DVD to model
        :present         => true,
        :controller_type => 'IDE',
        :mode            => 'persistent',
        :filename        => hostdrive,
        :uid_ems         => uid,
        :device_name     => name,
      }
      new_result
    end

    def process_iso_image(vm)
      vm[:DVDs].collect do |dvd|
        {
          :size            => dvd[:MS][:Size] / 1.megabyte,
          :device_type     => 'cdrom', # TODO: add DVD to model
          :present         => true,
          :controller_type => 'IDE',
          :mode            => 'persistent',
          :filename        => dvd[:MS][:SharePath],
          :uid_ems         => dvd[:MS][:ID],
          :device_name     => dvd[:MS][:Name],
        }
      end
    end

    def process_vm_storages(properties)
      return if properties[:VirtualHardDisks].nil?

      properties[:VirtualHardDisks].collect do |vhd|
        @data_index.fetch_path(:storages, vhd[:Props][:HostVolumeId])
      end.compact.uniq
    end

    def process_vm_storage(vmcpath, host)
      return nil if vmcpath.nil? || host.nil?

      mount_point  = vmcpath.match(DRIVE_LETTER).to_s
      return nil if mount_point.nil?

      mapping = @data_index.fetch_path(:host_uid_to_datastore_mount_point_mapping, host[:uid_ems])
      mapping[mount_point]
    end

    def process_os(property_hash)
      {
        :product_name => property_hash[:OperatingSystem][:ToString],
        :version      => property_hash[:OperatingSystemVersion],
        :product_type => "microsoft"
      }
    end

    def process_vm_os(os)
      return nil if os.nil?

      {
        :product_name => os[:Props][:Name]
      }
    end

    def process_tools_status(property_hash)
      tools = {
        "OS shutdown"          => property_hash[:OperatingSystemShutdownEnabled],
        "Time synchronization" => property_hash[:TimeSynchronizationEnabled],
        "Data exchange"        => property_hash[:DataExchangeEnabled],
        "Heartbeat"            => property_hash[:HeartbeatEnabled],
        "Backup"               => property_hash[:BackupEnabled],
      }

      tools.collect { |kv| kv.join(": ") }.join(", ").truncate(255).chomp(", ")
    end

    def set_relationship_on_hosts(cluster, nodes)
      nodes.each do |host|
        host = @data_index.fetch_path(:hosts, host[:Props][:ID])
        host[:ems_cluster] = cluster unless host.nil?
      end
    end

    def create_relationship_tree
      # HACK: creating a VMware type relationship tree to fit into the UI which
      # was designed specifically for a VMware hierarchy.

      host_folder = {
        :name         => 'host',
        :type         => 'EmsFolder',
        :uid_ems      => "host_folder",
        :ems_ref      => "host_folder",
        :hidden       => true,
        :ems_children => set_host_folder_children

      }
      vm_folder = {
        :name         => 'vm',
        :type         => 'EmsFolder',
        :uid_ems      => "vm_folder",
        :ems_ref      => "vm_folder",
        :hidden       => true,
        :ems_children => {:vms => @data[:vms]}
      }
      scvmm_folder = {
        :name         => 'SCVMM',
        :type         => 'Datacenter',
        :uid_ems      => "scvmm",
        :ems_ref      => "scvmm",
        :hidden       => false,
        :ems_children => {:folders => [host_folder, vm_folder]}
      }
      dc_folder = {
        :name         => 'Datacenters',
        :type         => 'EmsFolder',
        :uid_ems      => 'root_dc',
        :ems_ref      => 'root_dc',
        :hidden       => true,
        :ems_children => {:folders => [scvmm_folder]}
      }
      @data[:folders]  = [dc_folder, scvmm_folder, host_folder, vm_folder]
      @data[:ems_root] = dc_folder
    end

    def set_host_folder_children
      results = {}
      results[:clusters] = @data[:clusters] unless @data[:clusters].empty?
      results[:hosts]    = unclustered_hosts

      results
    end

    def unclustered_hosts
      @data[:hosts].select { |h| h[:ems_cluster].nil? }
    end

    def identify_primary_ip(nics, host)
      prefix = "MIQ(#{self.class.name})##{__method__})"

      primary_ip = nics.select { |nic| nic[:Props][:UsedForManagement] == true }
      if primary_ip.empty?
        $scvmm_log.warn("#{prefix} Found no management IP for #{host}. Setting IP to nil")
        nil
      else
        primary_ip.fetch_path(0, :Props, :IPAddresses, 0, :ToString)
      end
    end

    def lookup_power_state(power_state_input)
      case power_state_input
      when "Running"  then "on"
      when "Paused", "Saved"   then "suspended"
      when "PowerOff" then "off"
      else                 "unknown"
      end
    end

    def lookup_connected_state(connected_state_input)
      case connected_state_input
      when "true", "Responding"
        "connected"
      when "false", "NotResponding", "AccessDenied", "NoConnection"
        "disconnected"
      else
        "unknown"
      end
    end

    def lookup_disk_type(disk)
      case disk[:VHDType]
      when "DynamicallyExpanding", "Expandable", "Differencing" # TODO: Add A New Type In Database For Differencing
        "thin"
      when "Fixed"
        "thick"
      else
        "unknown"
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

    def normalize_blank_property_str(property)
      property.blank? ? nil : property[:ToString]
    end

    def process_collection(collection, key)
      @data[key] ||= []
      return if collection.nil?

      collection.each do |item|
        uid, new_result = yield(item[1])
        next if new_result.nil?

        @data[key] << new_result
        @data_index.store_path(key, uid, new_result)
      end
    end
  end
end
