module ManageIQ::Providers::Oracle::InfraManager::RefreshParser
  #
  # EMS Inventory Parsing
  #

  def self.service_to_hashes(service)
    uids = {}
    result = {:uid_lookup => uids}

    result[:storages], uids[:storages] = repository_inv_to_hashes(service.repositories)
    result[:clusters], uids[:clusters], result[:resource_pools] = cluster_inv_to_hashes(service.server_pools)
    result[:hosts], uids[:hosts], uids[:lans], uids[:switches], uids[:guest_devices], uids[:scsi_luns] = server_inv_to_hashes(service.servers, uids[:clusters])
    result[:vms], uids[:vms] = vm_inv_to_hashes(service.vms, uids[:storages], uids[:clusters], uids[:hosts], uids[:lans])
    result[:folders] = datacenter_inv_to_hashes(uids[:clusters], uids[:vms], uids[:storages], uids[:hosts])

    # Link up the root folder
    result[:ems_root] = result[:folders].first

    result
  end

  def self.uri_to_ref(uri)
    uri.split('/ovm/core/wsapi/rest').last
  end

  def self.repository_inv_to_hashes(inv)
    result = []
    result_uids = {:storage_id => {}}
    return result, result_uids if inv.nil?

    inv.each do |repository_inv|
      mor = repository_inv.key

      fs = repository_inv.file_system

      new_result = {
        :ems_ref             => uri_to_ref(repository_inv.uri),
        :ems_ref_obj         => uri_to_ref(repository_inv.uri),
        :name                => repository_inv.name,
        :store_type          => 'ISCSI',
        :total_space         => fs.size,
        :free_space          => fs.free_size,
        :uncommitted         => fs.free_size,
        :multiplehostaccess  => true,
        :location            => fs.path
      }

      result << new_result
      result_uids[mor] = new_result
      result_uids[:storage_id][repository_inv.key] = new_result
    end

    return result, result_uids
  end

  def self.server_inv_to_hashes(inv, cluster_uids)
    result = []
    result_uids = {}
    lan_uids = {}
    switch_uids = {}
    guest_device_uids = {}
    scsi_lun_uids = {}
    return result, result_uids, lan_uids, switch_uids, guest_device_uids, scsi_lun_uids if inv.nil?

    inv.each do |server_inv|
      mor = server_inv.key

      hostname = server_inv.hostname

      run_state = server_inv.server_run_state

      down_states = [
        Fog::Oracle::ServerRunState::STOPPING,
        Fog::Oracle::ServerRunState::STOPPED,
        Fog::Oracle::ServerRunState::UNKNOWN
      ]

      if down_states.include?(run_state)
        _log.warn "Host [#{mor}] connection state is [#{run_state.inspect}].  Inventory data may be missing."
      end

      power_state, connection_state = case run_state
                                      when Fog::Oracle::ServerRunState::STOPPING then ['maintenance', 'connected']
                                      when Fog::Oracle::ServerRunState::STOPPED  then ['off',         'disconnected']
                                      when Fog::Oracle::ServerRunState::STARTING then ['maintenance', 'connected']
                                      when Fog::Oracle::ServerRunState::RUNNING  then ['on',          'connected']
                                      when Fog::Oracle::ServerRunState::UNKNOWN  then ['unknown',     'connected']
                                      end

      ipaddress = server_inv.ip_address

      # Collect the hardware, networking, and scsi inventories
      switches, switch_uids[mor], lan_uids[mor] = server_inv_to_switch_hashes(server_inv)

      hardware = server_inv_to_hardware_hash(server_inv)
      hardware[:guest_devices], guest_device_uids[mor] = server_inv_to_guest_device_hashes(server_inv, switch_uids[mor])
      hardware[:networks] = server_inv_to_network_hashes(server_inv, guest_device_uids[mor])

      new_result = {
        :type             => 'ManageIQ::Providers::Oracle::InfraManager::Host',
        :ems_ref          => uri_to_ref(server_inv.uri),
        :ems_ref_obj      => uri_to_ref(server_inv.uri),
        :name             => server_inv.name || hostname,
        :hostname         => hostname,
        :ipaddress        => ipaddress,
        :uid_ems          => server_inv.key,
        :vmm_vendor       => 'oracle',
        :vmm_product      => 'oraclevm',
        :vmm_version      => server_inv.ovm_version.split('-').first,
        :vmm_buildnumber  => server_inv.ovm_version.split('-').last,
        :connection_state => connection_state,
        :power_state      => power_state,

        :operating_system => server_inv_to_os_hash(server_inv, hostname),

        :ems_cluster      => cluster_uids[server_inv.server_pool_id["value"] + "_cluster"],
        :hardware         => hardware,
        :switches         => switches,

      }

      result << new_result
      result_uids[mor] = new_result
    end

    return result, result_uids, lan_uids, switch_uids, guest_device_uids, scsi_lun_uids
  end

  def self.server_inv_to_hardware_hash(inv)
    return nil if inv.nil?

    cpus = inv.cpus

    return nil if cpus.empty?

    cpu = cpus[0]

    {
      :cpu_type             => cpu.model_name,
      :manufacturer         => cpu.vendor_id,
      :model                => cpu.model_name,
      :cpu_speed            => 0,
      :memory_mb            => inv.memory,
      :cpu_sockets          => 1,
      :cpu_total_cores      => cpus.length,
      :cpu_cores_per_socket => cpus.length
    }
  end

  def self.server_inv_to_switch_hashes(inv)
    ports = inv.ethernet_ports

    result = []
    result_uids = {:pnic_id => {}}
    lan_uids    = {}
    return result, result_uids if ports.nil?

    ports.each do |port|
      network = port.network

      next if network.nil?

      network_id = network.key

      lan = {:name => network.name, :uid_ems => network_id, :tag => nil}
      lan_uids[network_id] = lan
      new_result = {
        :uid_ems => network_id,
        :name    => network.name,
        :lans    => [lan]
      }

      result << new_result
      result_uids[network_id] = new_result
    end

    return result, result_uids, lan_uids
  end

  def self.server_inv_to_guest_device_hashes(inv, switch_uids)
    ports = inv.ethernet_ports

    result = []
    result_uids = {}
    return result, result_uids if ports.nil?

    result_uids[:pnic] = {}
    ports.each do |port|
      network = port.network

      switch = nil

      unless network.nil?
        network_id = network.key

        switch = switch_uids[network_id]
      end

      new_result = {
        :uid_ems         => port.key,
        :device_name     => port.name,
        :device_type     => 'ethernet',
        :location        => port.interface_name,
        :present         => true,
        :controller_type => 'ethernet',
      }
      new_result[:switch] = switch unless switch.nil?

      result << new_result
      result_uids[:pnic][port.key] = new_result
    end

    return result, result_uids
  end

  def self.server_inv_to_network_hashes(inv, guest_device_uids)
    ports = inv.ethernet_ports

    result = []
    return result if ports.nil?

    ports.each do |port|
      uid = port.key
      guest_device = guest_device_uids.fetch_path(:pnic, uid)

      ips = port.ipaddresses

      next if ips.blank?

      ip = ips[0]

      new_result = {
        :description => port.name,
        :ipaddress   => ip.address,
        :subnet_mask => ip.netmask,
      }

      result << new_result
      guest_device[:network] = new_result unless guest_device.nil?
    end

    result
  end

  def self.server_inv_to_os_hash(inv, hostname)
    return nil if inv.nil?

    result = {:name => hostname}
    result[:product_name] = 'linux'
    result
  end

  def self.vm_inv_to_hashes(inv, storage_uids, cluster_uids, host_uids, lan_uids)
    result = []
    result_uids = {}
    guest_device_uids = {}
    return result, result_uids if inv.nil?

    inv.each do |vm_inv|
      mor = vm_inv.key

      template = vm_inv.vm_run_state == Fog::Oracle::VmRunState::TEMPLATE
      raw_power_state = template ? "never" : vm_inv.vm_run_state

      storages = []

      vm_inv.vm_disk_mappings.each do |mapping|
        virtual_disk = mapping.virtual_disk

        next unless virtual_disk.disk_type == Fog::Oracle::DiskType::VIRTUAL_DISK

        device_type = 'disk'

        storage_mor = virtual_disk.repository_id["value"]

        storages << storage_uids[storage_mor]
      end

      storages.compact!
      storages.uniq!

      storage = storages.first

      host = nil

      unless vm_inv.server_id.nil?
        server_id = vm_inv.server_id["value"]
        host = host_uids.values.detect { |h| h[:uid_ems] == server_id }
      end

      ems_cluster = nil

      unless vm_inv.server_pool_id.nil?
        ems_cluster = cluster_uids[vm_inv.server_pool_id["value"] + "_cluster"]
      end

      host_mor = server_id
      hardware = vm_inv_to_hardware_hash(vm_inv)
      hardware[:disks] = vm_inv_to_disk_hashes(vm_inv, storage_uids)
      hardware[:guest_devices], guest_device_uids[mor] = vm_inv_to_guest_device_hashes(vm_inv, lan_uids[host_mor])
      hardware[:networks] = vm_inv_to_network_hashes(vm_inv)

      new_result = {
        :type              => template ? "ManageIQ::Providers::Oracle::InfraManager::Template" : "ManageIQ::Providers::Oracle::InfraManager::Vm",
        :ems_ref           => uri_to_ref(vm_inv.uri),
        :ems_ref_obj       => uri_to_ref(vm_inv.uri),
        :uid_ems           => vm_inv.key,
        :name              => vm_inv.name,
        :vendor            => "oracle",
        :raw_power_state   => raw_power_state,
        :location          => vm_inv.name,
        :boot_time         => nil,
        :connection_state  => 'connected',
        :template          => template,
        :host              => host,
        :ems_cluster       => ems_cluster,
        :storages          => storages,
        :storage           => storage,
        :operating_system  => vm_inv_to_os_hash(vm_inv),
        :hardware          => hardware,
        :snapshots         => []
      }

      # Attach to the cluster's default resource pool
      ems_cluster[:ems_children][:resource_pools].first[:ems_children][:vms] << new_result if ems_cluster && !template

      result << new_result
      result_uids[mor] = new_result
    end

    return result, result_uids
  end

  def self.vm_inv_to_hardware_hash(inv)
    return nil if inv.nil?

    result = {
      :guest_os   => inv.os_type,
      :annotation => inv.description
    }

    result[:cpu_cores_per_socket] = inv.cpu_count
    result[:cpu_sockets]          = 1
    result[:cpu_total_cores]      = inv.cpu_count

    result[:memory_mb] = inv.memory

    result
  end

  def self.vm_inv_to_guest_device_hashes(inv, lan_uids)
    inv = inv.virtual_nics

    result = []
    result_uids = {}
    return result, result_uids if inv.nil?

    inv.each do |vnic|
      uid = vnic.key
      address = vnic.mac_address
      name = vnic.name

      lan = lan_uids[vnic.network_id["value"]] unless lan_uids.nil?

      new_result = {
        :uid_ems         => uid,
        :device_name     => name,
        :device_type     => 'ethernet',
        :controller_type => 'ethernet',
        :address         => address,
      }
      new_result[:lan] = lan unless lan.nil?

      result << new_result
      result_uids[uid] = new_result
    end

    return result, result_uids
  end

  def self.vm_inv_to_network_hashes(inv)
    inv = inv.virtual_nics

    result = []
    return result if inv.nil?

    inv.each do |vnic|
      vnic.ip_addresses.each do |ip|
        new_result = {}
        new_result[:ipaddress] = ip.address

        result << new_result unless new_result.blank?
      end
    end

    result
  end

  def self.vm_inv_to_disk_hashes(inv, storage_uids)
    inv = inv.vm_disk_mappings

    result = []
    return result if inv.nil?

    inv.each do |mapping|
      virtual_disk = mapping.virtual_disk

      next unless virtual_disk.disk_type == Fog::Oracle::DiskType::VIRTUAL_DISK

      device_type = 'disk'

      storage_mor = virtual_disk.repository_id["value"]

      new_result = {
        :device_name     => virtual_disk.name,
        :device_type     => device_type,
        :controller_type => 'Block',
        :present         => true,
        :filename        => virtual_disk.key,
        :location        => virtual_disk.path,
        :size            => virtual_disk.size,
        :disk_type       => 'thick',
        :mode            => 'persistent'
      }

      new_result[:storage] = storage_uids[storage_mor] unless storage_mor.nil?
      result << new_result
    end

    result
  end

  def self.vm_inv_to_os_hash(inv)
    guest_os = inv.os_type
    result = {
      # If the data from VC is empty, default to "Other"
      :product_name => guest_os.blank? ? "Other" : guest_os
    }
    result[:system_type] = guest_os
    result
  end

  def self.cluster_inv_to_hashes(inv)
    result = []
    result_uids = {}
    result_res_pools = []
    return result, result_uids, result_res_pools if inv.nil?

    inv.each do |data|
      mor = "#{data.key}_cluster"

      # Create a default Resource Pool for the cluster
      default_res_pool = {
        :name         => data.name,
        :uid_ems      => data.key,
        :is_default   => true,
        :ems_children => {:vms => []}
      }
      result_res_pools << default_res_pool

      new_result = {
        :uid_ems       => mor,
        :name          => "#{data.name} Cluster",
        :ems_children  => {:resource_pools => [default_res_pool]}
      }

      result << new_result
      result_uids[mor] = new_result
    end

    return result, result_uids, result_res_pools
  end

  def self.datacenter_inv_to_hashes(cluster_uids, vm_uids, storage_uids, host_uids)
    result = [{
      :name          => 'Datacenters',
      :is_datacenter => false,
      :uid_ems       => 'root_dc',

      :ems_children  => {:folders => []}
    }]

    root_children = result.first[:ems_children][:folders]

    host_folder = {:name => 'host', :is_datacenter => false, :uid_ems => "default_dc_host"}
    vm_folder   = {:name => 'vm',   :is_datacenter => false, :uid_ems => "default_dc_vm"}

    host_folder[:ems_children] = {:clusters => cluster_uids.values}
    vm_folder[:ems_children] = {:vms => vm_uids.values}

    new_result = {
      :name          => 'Default',
      :is_datacenter => true,
      :uid_ems       => 'default_dc',
      :ems_children  => {:folders => [host_folder, vm_folder]}
    }

    result << new_result
    result << host_folder
    result << vm_folder
    root_children << new_result

    result
  end
end
