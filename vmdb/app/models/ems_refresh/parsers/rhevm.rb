module EmsRefresh::Parsers::Rhevm
  #
  # EMS Inventory Parsing
  #

  def self.ems_inv_to_hashes(inv)
    uids = {}
    result = {:uid_lookup => uids}

    result[:storages], uids[:storages] = self.storage_inv_to_hashes(inv[:storage])
    result[:clusters], uids[:clusters], result[:resource_pools] = self.cluster_inv_to_hashes(inv[:cluster])
    result[:hosts], uids[:hosts], uids[:lans], uids[:switches], uids[:guest_devices], uids[:scsi_luns] = self.host_inv_to_hashes(inv[:host], inv, uids[:clusters], uids[:storages])
    result[:vms], uids[:vms] = self.vm_inv_to_hashes(inv[:vm] + inv[:template], inv[:storage], uids[:storages], uids[:clusters], uids[:hosts], uids[:lans])
    result[:folders] = self.datacenter_inv_to_hashes(inv[:datacenter], uids[:clusters], uids[:vms], uids[:storages], uids[:hosts])

    # Link up the root folder
    result[:ems_root] = result[:folders].first

    # Clean up the temporary cluster-datacenter references
    result[:clusters].each { |c| c.delete(:datacenter_id) }

    return result
  end

  def self.storage_inv_to_hashes(inv)
    result = []
    result_uids = {:storage_id => {}}
    return result, result_uids if inv.nil?

    inv.each do |storage_inv|
      mor = storage_inv[:id]

      storage_type = storage_inv[:storage][:type].to_s.upcase
      location = if storage_type == 'NFS'
        "#{storage_inv[:storage][:address]}:#{storage_inv[:storage][:path]}"
      else
        storage_inv.attributes.fetch_path(:storage, :volume_group, :logical_unit, :id)
      end

      free        = storage_inv[:available].to_i
      used        = storage_inv[:used].to_i
      total       = free + used
      committed   = storage_inv[:committed].to_i
      uncommitted = total - committed

      new_result = {
        :ems_ref            => storage_inv[:href],
        :ems_ref_obj        => storage_inv[:href],
        :name               => storage_inv[:name],
        :store_type         => storage_type,
        :storage_domain_type => storage_inv[:type].try(:downcase),
        :total_space        => total,
        :free_space         => free,
        :uncommitted        => uncommitted,
        :multiplehostaccess => true,
        :location           => location,
        :master             => storage_inv[:master]
      }

      result << new_result
      result_uids[mor] = new_result
      result_uids[:storage_id][storage_inv[:id]] = new_result
    end
    return result, result_uids
  end

  def self.host_inv_to_hashes(inv, ems_inv, cluster_uids, storage_uids)
    result = []
    result_uids = {}
    lan_uids = {}
    switch_uids = {}
    guest_device_uids = {}
    scsi_lun_uids = {}
    return result, result_uids, lan_uids, switch_uids, guest_device_uids, scsi_lun_uids if inv.nil?

    log_header = "MIQ(#{self.name.split("::").last}-host_inv_to_hashes)"

    inv.each do |host_inv|
      mor = host_inv[:id]

      hostname = host_inv[:address]
#      domain_name = dns_config["domainName"] unless dns_config.nil?

      # Check connection state and log potential issues
      power_state = host_inv.attributes.fetch_path(:status, :state)
      if ['down', nil, ''].include?(power_state)
        $log.warn "#{log_header} Host [#{mor}] connection state is [#{power_state.inspect}].  Inventory data may be missing."
      end

      power_state, connection_state = case power_state
        when 'up'             then ['on',         'connected'   ]
        when 'maintenance'    then [power_state,  'connected'   ]
        when 'down'           then ['off',        'disconnected']
        when 'non_responsive' then ['unknown',    'connected'   ]
        else [power_state, 'disconnected']
      end

      # Remove the domain suffix if it is included in the hostname
      hostname = hostname.split(',').first
      # Get the IP address
      ipaddress = self.host_inv_to_ip(host_inv, hostname) || host_inv[:address]

      # Collect the hardware, networking, and scsi inventories
      switches, switch_uids[mor], lan_uids[mor] = self.host_inv_to_switch_hashes(host_inv, ems_inv)
#      lans, lan_uids[mor] = self.host_inv_to_lan_hashes(host_inv, switch_uids[mor])

      hardware = self.host_inv_to_hardware_hash(host_inv)
      hardware[:guest_devices], guest_device_uids[mor] = self.host_inv_to_guest_device_hashes(host_inv, switch_uids[mor], ems_inv)
      hardware[:networks] = self.host_inv_to_network_hashes(host_inv, guest_device_uids[mor])

      ipmi_address = nil
      if host_inv.attributes.fetch_path(:power_management, :type).to_s.include?('ipmi')
        ipmi_address = host_inv.attributes.fetch_path(:power_management, :address)
      end

      new_result = {
        :type => 'HostRedhat',
        :ems_ref => host_inv[:href],
        :ems_ref_obj => host_inv[:href],
        :name => host_inv[:name] || hostname,
        :hostname => hostname,
        :ipaddress => ipaddress,
        :uid_ems => host_inv[:id],
        :vmm_vendor => 'redhat',
        :vmm_product => host_inv[:type],
        :connection_state => connection_state,
        :power_state => power_state,

        :operating_system => self.host_inv_to_os_hash(host_inv, hostname),

        :ems_cluster => cluster_uids[host_inv.attributes.fetch_path(:cluster, :id)],
        :hardware => hardware,
        :switches => switches,

      }
      new_result[:ipmi_address] = ipmi_address unless ipmi_address.blank?

      result << new_result
      result_uids[mor] = new_result
    end
    return result, result_uids, lan_uids, switch_uids, guest_device_uids, scsi_lun_uids
  end

  def self.host_inv_to_ip(inv, hostname = nil)
    log_header = "MIQ(#{self.name.split("::").last}.host_inv_to_ip)"
    $log.debug("#{log_header} IP lookup for host in VIM inventory data...") if $log
    ipaddress = nil

    inv[:host_nics].to_miq_a.each do |nic|
      ip_data = nic[:ip]
      if !ip_data[:gateway].blank? && !ip_data[:address].blank?
        ipaddress = ip_data[:address]
        break
      end
    end

    if !ipaddress.nil?
      warn_msg = "#{log_header} IP lookup for host in VIM inventory data...Failed."
      if [nil, "localhost", "localhost.localdomain", "127.0.0.1"].include?(hostname)
        $log.warn warn_msg  if $log
      else
        $log.warn "#{warn_msg} Falling back to reverse lookup." if $log
        begin
          # IPSocket.getaddress(hostname) is not used because it was appending
          #   a ".com" to the "esxdev001.localdomain" which resolved to a real
          #   internet address. Socket.getaddrinfo does the right thing.
          # TODO: Can this moved to MiqSockUtil?

          #$log.debug "#{log_header} IP lookup by hostname [#{hostname}]..."
          ipaddress = Socket.getaddrinfo(hostname, nil)[0][3]
          $log.debug "#{log_header} IP lookup by hostname [#{hostname}]...Complete: IP found: [#{ipaddress}]" if $log
        rescue => err
          $log.warn "#{log_header} IP lookup by hostname [#{hostname}]...Failed with the following error: #{err}" if $log
        end
      end
    end

    return ipaddress
  end

  def self.host_inv_to_hardware_hash(inv)
    return nil if inv.nil?

    result = {}

    hdw = inv[:cpu]
    unless hdw.blank?
      result[:cpu_speed] = hdw[:speed] unless hdw[:speed].blank?
      result[:cpu_type] = hdw[:name] unless hdw[:name].blank?

      # Value provided by VC is in bytes, need to convert to MB
      memory_total = inv[:statistics].to_miq_a.detect {|stat| stat[:name] == 'memory.total'}
      result[:memory_cpu] = memory_total.nil? ? 0 : memory_total[:values].first.to_i / 1048576  # in MB

      result[:cores_per_socket] = hdw.fetch_path(:topology, :cores) || 1        # Number of cores per socket
      result[:numvcpus]         = hdw.fetch_path(:topology, :sockets) || 1      # Number of physical sockets
      result[:logical_cpus]     = result[:numvcpus] * result[:cores_per_socket] # Number of cores multiplied by sockets
    end

    return result
  end

  def self.host_inv_to_switch_hashes(inv, ems_inv)
    nics = inv[:host_nics]

    result = []
    result_uids = {:pnic_id => {}}
    lan_uids    = {}
    return result, result_uids if nics.nil?

    nics.to_miq_a.each do |data|
      network_id = data.attributes.fetch_path(:network, :id)
      unless network_id.nil?
        network = ems_inv[:network].detect {|n| n[:id] == network_id}
      else
        network_name = data.attributes.fetch_path(:network, :name)
        cluster_id = inv.attributes.fetch_path(:cluster, :id)
        cluster = ems_inv[:cluster].detect {|c| c[:id] == cluster_id}
        datacenter_id = cluster.attributes.fetch_path(:data_center, :id)
        network = ems_inv[:network].detect {|n| n[:name] == network_name && n.attributes.fetch_path(:data_center, :id) == datacenter_id}
      end

      tag_value = nil
      unless network.nil?
        uid = network[:id]
        name = network[:name]
        tag_value = network.attributes.fetch_path(:vlan, :id)
      else
        uid = name = network_name unless network_name.nil?
      end

      next if uid.nil?

      lan = {:name => name, :uid_ems => uid, :tag => tag_value}
      lan_uids[uid] = lan
      new_result = {
        :uid_ems => uid,
        :name => name,

        :lans => [{:name => name, :uid_ems => uid, :tag => tag_value}]
      }

      result << new_result
      result_uids[uid] = new_result

#      pnics.each { |pnic| result_uids[:pnic_id][pnic] = new_result unless pnic.blank? }
    end
    return result, result_uids, lan_uids
  end

  def self.host_inv_to_guest_device_hashes(inv, switch_uids, ems_inv)
    pnic = inv[:host_nics]

    result = []
    result_uids = {}
    return result, result_uids if pnic.nil?

    result_uids[:pnic] = {}
    pnic.to_miq_a.each do |data|
      # Find the switch to which this pnic is connected
      network_id = data.attributes.fetch_path(:network, :id)
      unless network_id.nil?
        network = ems_inv[:network].detect {|n| n[:id] == network_id}
      else
        network_name = data.attributes.fetch_path(:network, :name)
        cluster_id = inv.attributes.fetch_path(:cluster, :id)
        cluster = ems_inv[:cluster].detect {|c| c[:id] == cluster_id}
        datacenter_id = cluster.attributes.fetch_path(:data_center, :id)
        network = ems_inv[:network].detect {|n| n[:name] == network_name && n.attributes.fetch_path(:data_center, :id) == datacenter_id}
      end

      unless network.nil?
        switch_uid = network[:id]
      else
        switch_uid = network_name unless network_name.nil?
      end

      unless switch_uid.nil?
        switch = switch_uids[switch_uid]
      end

      location = nil
      location = $1 if data[:name] =~ /(\d+)$/
      uid = data[:id]

      new_result = {
        :uid_ems => uid,
        :device_name => data[:name],
        :device_type => 'ethernet',
        :location => location,
        :present => true,
        :controller_type => 'ethernet',
      }
      new_result[:switch] = switch unless switch.nil?

      result << new_result
      result_uids[:pnic][uid] = new_result
    end

    return result, result_uids
  end

  def self.host_inv_to_network_hashes(inv, guest_device_uids)
    inv = inv[:host_nics]
    result = []
    return result if inv.nil?

    inv.to_miq_a.each do |vnic|

      uid = vnic[:id]
      guest_device = guest_device_uids.fetch_path(:pnic, uid)

      # Get the ip section
      ip = vnic[:ip]

      new_result = {
        :description => vnic[:name],
        :ipaddress => ip[:address],
        :subnet_mask => ip[:netmask],
      }

      result << new_result
      guest_device[:network] = new_result unless guest_device.nil?
    end
    return result
  end

  def self.host_inv_to_os_hash(inv, hostname)
    return nil if inv.nil?

    result = {:name => hostname}
    result[:product_name] = 'linux'
    return result
  end

  def self.vm_inv_to_hashes(inv, storage_inv, storage_uids, cluster_uids, host_uids, lan_uids)
    result = []
    result_uids = {}
    guest_device_uids = {}
    return result, result_uids if inv.nil?

    inv.each do |vm_inv|
      mor = vm_inv[:id]

      # Skip the place holder template since it does not really exist and does not have a unique ID accross multiple Management Systems
      next if mor == '00000000-0000-0000-0000-000000000000'

      template        = vm_inv[:href].include?('/templates/')
      raw_power_state = template ? "never" : vm_inv.attributes.fetch_path(:status, :state)

      boot_time = vm_inv[:start_time].blank? ? nil : vm_inv[:start_time]

      storages = []
      vm_inv[:disks].to_miq_a.each do |disk|
        disk[:storage_domains].to_miq_a.each do |sd|
          storages << storage_uids[sd[:id]]
        end
      end
      storages.compact!
      storages.uniq!
      storage = storages.first

      # Determine the cluster
      ems_cluster = cluster_uids[vm_inv.attributes.fetch_path(:cluster, :id)]

      # If the VM is running it will have a host name in the data
      # Otherwise if it is assigned to run on a specific host the host ID will be in the placement_policy
      host_id = vm_inv.attributes.fetch_path(:host, :id)
      host_id = vm_inv.attributes.fetch_path(:placement_policy, :host, :id) if host_id.blank?
      host = host_uids.values.detect {|h| h[:uid_ems] == host_id} unless host_id.blank?

      host_mor = host_id
      hardware = self.vm_inv_to_hardware_hash(vm_inv)
      hardware[:disks] = self.vm_inv_to_disk_hashes(vm_inv, storage_uids)
      hardware[:guest_devices], guest_device_uids[mor] = self.vm_inv_to_guest_device_hashes(vm_inv, lan_uids[host_mor])
      hardware[:networks] = self.vm_inv_to_network_hashes(vm_inv, guest_device_uids[mor])

      new_result = {
        :type              => template ? "TemplateRedhat" : "VmRedhat",
        :ems_ref           => vm_inv[:href],
        :ems_ref_obj       => vm_inv[:href],
        :uid_ems           => vm_inv[:id],
        :name              => URI.decode(vm_inv[:name]),
        :vendor            => "redhat",
        :raw_power_state   => raw_power_state,
        :location          => "#{vm_inv[:id]}.ovf",
        :boot_time         => boot_time,
        :connection_state  => 'connected',
        :template          => template,
        :host              => host,
        :ems_cluster       => ems_cluster,
        :storages          => storages,
        :storage           => storage,
        :operating_system  => self.vm_inv_to_os_hash(vm_inv),
        :hardware          => hardware,
        :custom_attributes => self.vm_inv_to_custom_attribute_hashes(vm_inv),
        :snapshots         => self.vm_inv_to_snapshot_hashes(vm_inv),
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
      :guest_os   => inv.attributes.fetch_path(:os, :type),
      :annotation => inv[:description]
    }

    hdw = inv[:cpu]
    result[:cores_per_socket] = hdw.fetch_path(:topology, :cores) || 1        # Number of cores per socket
    result[:numvcpus]         = hdw.fetch_path(:topology, :sockets) || 1      # Number of sockets
    result[:logical_cpus]     = result[:numvcpus] * result[:cores_per_socket] # Number of cores multiplied by sockets

    result[:memory_cpu] = inv[:memory] / 1048576  # in MB

    return result
  end

  def self.vm_inv_to_guest_device_hashes(inv, lan_uids)
    inv = inv[:nics]

    result = []
    result_uids = {}
    return result, result_uids if inv.nil?

    inv.to_miq_a.each do |data|
      uid = data[:id]
      address = data.attributes.fetch_path(:mac, :address)
      name = data[:name]

      lan = lan_uids[data.attributes.fetch_path(:network, :id)] unless lan_uids.nil?

      new_result = {
        :uid_ems => uid,
        :device_name => name,
        :device_type => 'ethernet',
        :controller_type => 'ethernet',
        :address => address,
      }
      new_result[:lan] = lan unless lan.nil?

      result << new_result
      result_uids[uid] = new_result
    end
    return result, result_uids
  end

  def self.vm_inv_to_network_hashes(inv, guest_device_uids)
    inv_net = inv.attributes.fetch_path(:guest_info, :ips)

    result = []
    return result if inv_net.nil?

    inv_net.to_miq_a.each do |data|
      new_result = {}
      new_result[:ipaddress] = data[:address]

      result << new_result unless new_result.blank?
    end

    # There is not data to corridnate what IPs go with what networks
    # So if there is only 1 of each link them together.
    if result.length == 1 && guest_device_uids.length == 1
      guest_device = guest_device_uids[guest_device_uids.keys.first]
      guest_device[:network] = result.first unless guest_device.nil?
    end

    return result
  end

  def self.vm_inv_to_disk_hashes(inv, storage_uids)
    inv = inv[:disks]

    result = []
    return result if inv.nil?

    # RHEV initially orders disks by bootable status then by name. Attempt
    # to use the disk number in the name, if available, as an ordering hint
    # to support the case where a disk is added after initial VM creation.
    inv = inv.to_miq_a.sort_by do |disk|
      match = disk[:name].match(/disk[^\d]*(?<index>\d+)/i)
      [disk[:bootable] ? 0 : 1, match ? match[:index].to_i : Float::INFINITY, disk[:name]]
    end.group_by { |d| d[:interface] }

    inv.each do |interface, devices|
      devices.each_with_index do |device, index|
        device_type = 'disk'

        storage_domain = device[:storage_domains].first
        storage_mor = storage_domain && storage_domain[:id]

        new_result = {
          :device_name     => device[:name],
          :device_type     => device_type,
          :controller_type => interface,
          :present         => true,
          :filename        => device[:id],
          :location        => index.to_s,
          :size            => device[:size].to_i,
          :disk_type       => device[:sparse] == true ? 'thin' : 'thick',
          :mode            => 'persistent'
        }

        new_result[:storage] = storage_uids[storage_mor] unless storage_mor.nil?
        result << new_result
      end
    end

    return result
  end

  def self.vm_inv_to_os_hash(inv)
    guest_os = inv.attributes.fetch_path(:os, :type)
    result = {
      # If the data from VC is empty, default to "Other"
      :product_name => guest_os.blank? ? "Other" : guest_os
    }
    result[:system_type] = inv[:type] unless inv[:type].nil?
    return result
  end

  def self.vm_inv_to_snapshot_hashes(inv)
    result = []
    inv = inv[:snapshots].to_miq_a.reverse
    return result if inv.nil?

    parent_id = nil
    inv.each_with_index do |snapshot, idx|
      result << self.snapshot_inv_to_snapshot_hashes(snapshot, idx == inv.length-1, parent_id)
      parent_id = snapshot[:id]
    end
    return result
  end

  def self.snapshot_inv_to_snapshot_hashes(inv, current, parent_uid=nil)
    create_time = inv[:date].getutc
    create_time_ems = create_time.iso8601(6)

    # Fix case where blank description comes back as a Hash instead
    name = description = inv[:description]
    name = "Active Image" if name[0,13] == '_ActiveImage_'

    result = {
      :uid_ems     => inv[:id],
      :uid         => inv[:id],
      :parent_uid  => parent_uid,
      :name        => name,
      :description => description,
      :create_time => create_time,
      :current     => current,
    }

    return result
  end

  def self.vm_inv_to_custom_attribute_hashes(inv)
    result = []
    custom_attrs = inv[:custom_attributes]
    return result if custom_attrs.nil?

    custom_attrs.each do |ca|
      new_result = {
        :section => 'custom_field',
        :name    => ca[:name],
        :value   => ca[:value].try(:truncate, 255),
        :source  => "VC",
      }
      result << new_result
    end

    return result
  end


  def self.cluster_inv_to_hashes(inv)
    result = []
    result_uids = {}
    result_res_pools = []
    return result, result_uids, result_res_pools if inv.nil?

    inv.each do |data|
      mor = data[:id]

      # Create a default Resource Pool for the cluster
      default_res_pool = {
        :name         => "Default for Cluster #{data[:name]}",
        :uid_ems      => "#{data[:id]}_respool",
        :is_default   => true,
        :ems_children => {:vms => []}
      }
      result_res_pools << default_res_pool

#      config = data["configuration"]
#      das_config = config["dasConfig"]
#      drs_config = config["drsConfig"]

      new_result = {
        :ems_ref => data[:href],
        :ems_ref_obj => data[:href],
        :uid_ems => data[:id],
        :name => data[:name],

        # Capture datacenter id so we can link up to it's sub-folders later
        :datacenter_id => data.attributes.fetch_path(:data_center, :id),

        :ems_children => {:resource_pools => [default_res_pool]}
      }

      result << new_result
      result_uids[mor] = new_result
    end
    return result, result_uids, result_res_pools
  end

  def self.datacenter_inv_to_hashes(inv, cluster_uids, vm_uids, storage_uids, host_uids)
    result = [{
      :name          => 'Datacenters',
      :is_datacenter => false,
      :uid_ems       => 'root_dc',

      :ems_children  => {:folders => []}
    }]
    return result if inv.nil?

    root_children = result.first[:ems_children][:folders]

    inv.each do |data|
      uid = data[:id]

      host_folder = {:name => 'host', :is_datacenter => false, :uid_ems => "#{uid}_host"}
      vm_folder   = {:name => 'vm',   :is_datacenter => false, :uid_ems => "#{uid}_vm"}

      # Link clusters to datacenter host folder
      clusters = cluster_uids.values.select { |c| c[:datacenter_id] == uid }
      host_folder[:ems_children] = {:clusters => clusters}

      # Link vms to datacenter vm folder
      vms = vm_uids.values.select { |v| v.fetch_path(:ems_cluster, :datacenter_id) == uid }
      vm_folder[:ems_children] = {:vms => vms}

      new_result = {
        :name          => data[:name],
        :is_datacenter => true,
        :ems_ref       => data[:href],
        :ems_ref_obj   => data[:href],
        :uid_ems       => uid,

        :ems_children  => {:folders => [host_folder, vm_folder]}
      }

      result << new_result
      result << host_folder
      result << vm_folder
      root_children << new_result

      # Link hosts to storages
      hosts = host_uids.values.select { |v| v.fetch_path(:ems_cluster, :datacenter_id) == uid }
      storage_ids = data[:storagedomains].to_miq_a.collect { |s| s[:id] }
      hosts.each { |h| h[:storages] = storage_uids.values_at(*storage_ids).compact } unless storage_ids.blank?
    end

    result
  end
end
