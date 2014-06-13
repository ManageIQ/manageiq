$:.push("#{File.dirname(__FILE__)}/../util")
require 'miq-extensions'
require 'miq-unicode'

require 'digest/md5'

module MiqHypervInventoryParser

  #
  # EMS Inventory Parsing
  #

  def self.ems_inv_to_hashes(inv)
    uids = {}
    result = {:uid_lookup => uids}

    result[:storages], uids[:storages] = self.storage_inv_to_hashes(inv[:storage])
    result[:hosts], uids[:hosts], uids[:lans], uids[:switches], uids[:guest_devices], uids[:scsi_luns] = self.host_inv_to_hashes(inv[:host], inv, uids[:storages])
    result[:vms], uids[:vms] = self.vm_inv_to_hashes(inv[:vm], inv[:storage], uids[:storages], uids[:hosts], uids[:lans])

    # We know all the VMs belong to the single host
    result[:hosts][0][:vms] = result[:vms]

    #result[:folders], uids[:folders] = self.folder_and_dc_inv_to_hashes(inv[:folder], inv[:dc])
    #result[:clusters], uids[:clusters] = self.cluster_inv_to_hashes(inv[:cluster])
    #result[:resource_pools], uids[:resource_pools] = self.rp_inv_to_hashes(inv[:rp])

    #self.link_ems_metadata(result, inv)
    #self.link_root_folder(result)
    #self.set_default_rps(result)

    return result
  end

  def self.storage_inv_to_hashes(inv)
    result = []
    result_uids = {:storage_id => {}}
    return result, result_uids if inv.nil?
    hostname = MiqSockUtil.getFullyQualifiedDomainName.downcase

    inv.each do |mor, storage|
      uid = storage.Path_.RelPath
      name = File.path_to_uri("#{storage.Name}\\", hostname)
      loc = storage.ProviderName.nil? ? name : storage.ProviderName

      new_result = {
        :name => name,
        #:store_type => storage.FileSystem.to_s.upcase,
        :store_type => 'NAS',
        :total_space => storage.Size,
        :free_space => storage.FreeSpace,
        :multiplehostaccess => storage.DriveType == 4,
        :location => loc,
      }

      result << new_result
      result_uids[mor] = new_result
      result_uids[:storage_id][uid] = new_result
    end
    return result, result_uids
  end

  def self.host_inv_to_hashes(inv, ems_inv, storage_uids)
    result = []
    result_uids = {}
    lan_uids = {}
    switch_uids = {}
    guest_device_uids = {}
    scsi_lun_uids = {}
    return result, result_uids, lan_uids, switch_uids, guest_device_uids, scsi_lun_uids if inv.nil?

    log_header = "MIQ(#{self.name.split("::").last}-host_inv_to_hashes)"

    inv.each do |mor, host_inv|

      hostname = MiqSockUtil.getFullyQualifiedDomainName

      # Get the IP address
      begin
        ipaddress = MiqSockUtil.getIpAddr
        $log.debug "#{log_header} IP lookup by hostname [#{hostname}] Completed...Returned IP: [#{ipaddress}]"
      rescue => err
        # If the Socket.getaddrinfo raises an error, attempt to find the IP
        # address in the VC data, otherwise, use the hostname of the machine
        $log.warn "#{log_header} IP lookup by hostname [#{hostname}] Failed with the following error: #{err}"
        ipaddress = self.host_inv_to_ip(host_inv) || hostname
        $log.debug "#{log_header} IP lookup by hostname [#{hostname}] instead using IP [#{ipaddress}]"
      end

      product = host_inv[:product]
      vendor = product['vendor'].to_s.downcase
      product_name = product["product"]

      power_state = host_inv[:runtime][:settings][:Msvm_VirtualSystemManagementService].blank? ? "off" : "on"

      # Collect the hardware, networking, and scsi inventories
      switches, switch_uids[mor] = self.host_inv_to_switch_hashes(host_inv)
      lans, lan_uids[mor] = self.host_inv_to_lan_hashes(host_inv, switch_uids[mor])

      hardware = self.host_inv_to_hardware_hash(host_inv)
      hardware[:guest_devices], guest_device_uids[mor] = self.host_inv_to_guest_device_hashes(host_inv, switch_uids[mor])
      hardware[:networks] = self.host_inv_to_network_hashes(host_inv, guest_device_uids[mor])

#      scsi_luns, scsi_lun_uids[mor] = self.host_inv_to_scsi_lun_hashes(host_inv)
#      scsi_targets = self.host_inv_to_scsi_target_hashes(host_inv, guest_device_uids[mor][:storage], scsi_lun_uids[mor])

      # Collect the resource pools inventory
#      parent_type, parent_mor, parent_data = self.host_parent_resource(mor, ems_inv)
#      rp_uids = parent_type == :host_res ? self.get_mors(parent_data, "resourcePool") : []

      # Link up the storages
      storages = storage_uids[:storage_id].collect {|k,v| v}

      new_result = {
        :name => hostname,
        :hostname => hostname,
        :ipaddress => ipaddress,
        :vmm_vendor => vendor,
        :vmm_version => product["version"],
        :vmm_product => product_name,
        :vmm_buildnumber => product["build"],
        :power_state => power_state,

        :operating_system => self.host_inv_to_os_hash(host_inv, hostname),
        :system_services => self.host_inv_to_system_service_hashes(host_inv),

        :hardware => hardware,
        :switches => switches,
        :storages => storages,

        #:child_uids => rp_uids,
      }
      result << new_result

      result_uids[mor] = new_result
    end
    return result, result_uids, lan_uids, switch_uids, guest_device_uids, scsi_lun_uids
  end

  def self.host_inv_to_ip(inv)
    # In the inventory for a specific host ook for the IP address in the
    # service console/vswif0 device. The data we are looking for should be
    # in ["config"]["network"]["consoleVnic"]["spec"]["ip"]["ipAddress"]

    log_header = "MIQ(#{self.name.split("::").last}-host_inv_to_ip)"
    $log.debug("#{log_header} IP lookup for host in VIM inventory data...")

    cons_vnics = inv.fetch_path('config', 'network', 'consoleVnic')
    $log.debug("#{log_header} consoleVnic [#{cons_vnics.inspect}]")

    # Go into each device type, looking for the service console/vswif0 device
    cons_vnics.to_miq_a.each do |cons_vnic|
      # Verify that we are at the vswif0, Service Console and the appropriate value exists
      next unless cons_vnic["device"].to_s.downcase == "vswif0" && cons_vnic["portgroup"].to_s.downcase == "service console"
      ip = cons_vnic.fetch_path("spec", "ip", "ipAddress")
      next if ip.nil?
      ip = ip.to_s

      # Test the ipaddress value to make sure it's an IP
      if ip =~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/
        $log.debug("#{log_header} IP lookup for host in VIM inventory data...Complete: IP found: [#{ip}]")
        return ip
      end

      $log.debug("#{log_header} #{ip} is NOT an IP address")
    end

    $log.debug("#{log_header} IP lookup for host in VIM inventory data...Complete: IP not found")
    return nil
  end

  def self.host_inv_to_os_hash(inv, hostname)
    os = inv[:config][:Win32_OperatingSystem]
    result = {:name => hostname}
    result[:product_name] = os.Caption
    result[:version] = os.Version
    result[:build_number] = os.BuildNumber
    result[:product_type] = 'ServerNT'
    return result
  end

  def self.host_inv_to_hardware_hash(inv)
    result = {}

    hdw = inv[:config][:Win32_ComputerSystem]
    processor = inv[:config][:Win32_Processor].first
    unless hdw.blank?
      result[:cpu_speed] = processor.MaxClockSpeed
      result[:cpu_type] = processor.Name
      result[:manufacturer] = hdw.Manufacturer
      result[:model] = hdw.Model
      result[:number_of_nics] = inv[:config][:Win32_NetworkAdapterConfiguration].length

      # Value provided by VC is in bytes, need to convert to MB
      result[:memory_cpu] = (hdw.TotalPhysicalMemory.to_f / 1048576).round

      result[:numvcpus] = hdw.NumberOfProcessors
      result[:logical_cpus] = hdw.NumberOfLogicalProcessors
      # Calculate the number of cores per socket by dividing total numCpuCores by numCpuPkgs
      result[:cores_per_socket] = (result[:logical_cpus].to_f / result[:numvcpus].to_f).to_i
    end

    result[:guest_os_full_name] = result[:guest_os] = inv[:config][:Win32_OperatingSystem].Caption

    #result[:vmotion_enabled] = config["vmotionEnabled"].to_s.downcase == "true" unless config["vmotionEnabled"].blank?

    #result[:cpu_usage] = quickStats["overallCpuUsage"] unless quickStats["overallCpuUsage"].blank?
    #result[:memory_usage] = quickStats["overallMemoryUsage"] unless quickStats["overallMemoryUsage"].blank?

    return result
  end

  def self.host_inv_to_switch_hashes(inv)
    switches = inv.fetch_path(:config, :network)

    result = []
    result_uids = {:pnic_id => {}}
    return result, result_uids if switches.nil?

    switches.to_miq_a.each do |data|
      name = data[:Msvm_VirtualSwitch].ElementName
      uid = data[:Msvm_VirtualSwitch].Name
      pnics = data[:switch_ports].collect{|sp| sp if sp.has_key?(:Msvm_ExternalEthernetPort)}.to_miq_a

      new_result = {
        :uid_ems => uid,
        :name => name,
        #:ports => data['numPorts'],

        :lans => []
      }
      result << new_result
      result_uids[uid] = new_result

      pnics.each { |pnic| result_uids[:pnic_id][pnic[:Msvm_ExternalEthernetPort].PermanentAddress] = new_result unless pnic.blank? }
    end
    return result, result_uids
  end

  def self.host_inv_to_lan_hashes(inv, switch_uids)
    switches = inv.fetch_path(:config, :network)

    result = []
    result_uids = {}
    return result, result_uids if switches.nil?

    switches.to_miq_a.each do |data|
      # Find the switch to which this lan is connected
      switch = switch_uids[data[:Msvm_VirtualSwitch].Name]
      next if switch.nil?

      name = data[:Msvm_VirtualSwitch].ElementName
      uid = data[:Msvm_VirtualSwitch].Name
      tag = 0
      switch_port = data[:switch_ports].first
      unless switch_port.nil?
        tag = switch_port[:Msvm_VLANEndpointSettingData].AccessVLAN unless switch_port[:Msvm_VLANEndpointSettingData].nil?
      end

      new_result = {
        :uid_ems => uid,
        :name => name,
        :tag => tag.to_s,
      }
      result << new_result
      result_uids[uid] = new_result
      switch[:lans] << new_result
    end
    return result, result_uids
  end

  def self.host_inv_to_guest_device_hashes(inv, switch_uids)
    config = inv[:config]

    result = []
    result_uids = {}
    return result, result_uids if config.nil?

    network = config[:Win32_NetworkAdapter]
    storage = config[:storageDevice]
    return result, result_uids if network.nil? && storage.nil?

    result_uids[:pnic] = {}
    unless network.nil?
      network.each do |data|
        # Find the switch to which this pnic is connected
        macaddr = data.MACAddress.gsub(':','')
        switch = switch_uids[:pnic_id][macaddr]
        next if switch.nil?

        net = config[:network].detect {|n| n[:Msvm_VirtualSwitch].Name == switch[:uid_ems]}
        nic = net[:switch_ports].detect {|sp| sp[:Win32_NetworkAdapter]}
        next if nic.nil?
        nic = nic[:Win32_NetworkAdapter]

        name = nic.Description
        uid = nic.GUID

        new_result = {
          :uid_ems => uid,
          :device_name => name,
          :device_type => 'ethernet',
          :location => nic.InterfaceIndex,
          :present => true,
          :controller_type => 'ethernet',
        }
        new_result[:switch] = switch unless switch.nil?

        result << new_result
        result_uids[:pnic][uid] = new_result
      end
    end

    result_uids[:storage] = {:adapter_id => {}}

    return result, result_uids
  end

  def self.host_inv_to_network_hashes(inv, guest_device_uids)
    inv = inv.fetch_path(:config, :Win32_NetworkAdapterConfiguration)
    result = []
    return result if inv.nil?

    inv.each do |network_cfg|
      # Find the pnic to which this service console is connected

      uid = network_cfg.Description
      guest_device = guest_device_uids.fetch_path(:pnic, uid)

      new_result = {
        :description => uid,
        :dhcp_enabled => network_cfg.DHCPEnabled,
        :ipaddress => network_cfg.IPAddress,
        :subnet_mask => network_cfg.IPSubnet.first,
      }

      result << new_result
      guest_device[:network] = new_result unless guest_device.nil?
    end
    return result
  end

  def self.host_inv_to_scsi_lun_hashes(inv)
    inv = inv.fetch_path('config', 'storageDevice')

    result = []
    result_uids = {}
    return result, result_uids if inv.nil?

    inv['scsiLun'].to_miq_a.each do |data|
      new_result = {
        :uid_ems => data['uuid'],

        :canonical_name => data['canonicalName'].blank? ? nil : data['canonicalName'],
        :lun_type => data['lunType'].blank? ? nil : data['lunType'],
        :device_name => data['deviceName'].blank? ? nil : data['deviceName'],
        :device_type => data['deviceType'].blank? ? nil : data['deviceType'],
      }

      # :lun will be set later when we link to scsi targets

      cap = data['capacity']
      if cap.nil?
        new_result[:block] = new_result[:block_size] = new_result[:capacity] = nil
      else
        block = cap['block'].blank? ? nil : cap['block']
        block_size = cap['blockSize'].blank? ? nil : cap['blockSize']

        new_result[:block] = block
        new_result[:block_size] = block_size
        new_result[:capacity] = (block.nil? || block_size.nil?) ? nil : ((block.to_i * block_size.to_i) / 1024)
      end

      result << new_result
      result_uids[data['key']] = new_result
    end

    return result, result_uids
  end

  def self.host_inv_to_scsi_target_hashes(inv, guest_device_uids, scsi_lun_uids)
    inv = inv.fetch_path('config', 'storageDevice', 'scsiTopology', 'adapter')

    result = []
    return result if inv.nil?

    inv.to_miq_a.each do |adapter|
      adapter['target'].to_miq_a.each do |data|
        target = uid = data['target'].to_s

        new_result = {
          :uid_ems => uid,
          :target => target
        }

        transport = data['transport']
        if transport.nil?
          new_result[:iscsi_name], new_result[:iscsi_alias], new_result[:address] = nil
        else
          new_result[:iscsi_name] = transport['iScsiName'].blank? ? nil : transport['iScsiName']
          new_result[:iscsi_alias] = transport['iScsiAlias'].blank? ? nil : transport['iScsiAlias']
          new_result[:address] = transport['address'].blank? ? nil : transport['address']
        end

        # Link the scsi target to the bus adapter
        guest_device = guest_device_uids[:adapter_id][adapter['adapter']]
        unless guest_device.nil?
          guest_device[:miq_scsi_targets] ||= []
          guest_device[:miq_scsi_targets] << new_result
        end

        # Link the scsi target to the scsi luns
        data['lun'].to_miq_a.each do |l|
          # We dup here so that later saving of ids doesn't cause a clash
          # TODO: Change this if we get to a better normalized structure in
          #   the database.
          lun = scsi_lun_uids[l['scsiLun']].dup
          unless lun.nil?
            lun[:lun] = l['lun'].to_s

            new_result[:miq_scsi_luns] ||= []
            new_result[:miq_scsi_luns] << lun
          end
        end

        result << new_result
      end
    end
    return result
  end

  def self.host_inv_to_system_service_hashes(inv)
    inv = inv.fetch_path(:config, :Win32_Service)

    result = []
    return result if inv.nil?

    inv.each do |data|
      result << {
        :name => data.Name.AsciiToUtf8,
        :display_name => data.Caption.to_s.AsciiToUtf8,
        :description => data.Description.to_s.AsciiToUtf8,
        :running => data.Started,
        :image_path => data.PathName.to_s.AsciiToUtf8,
        :svc_type => data.ServiceType,
        :start => data.StartMode
      }
    end
    return result
  end

  def self.vm_inv_to_hashes(inv, storage_inv, storage_uids, host_uids, lan_uids)
    result = []
    result_uids = {}
    guest_device_uids = {}
    return result, result_uids if inv.nil?

    log_header = "MIQ(#{self.name.split("::").last}-vm_inv_to_hashes)"

    inv.each do |mor, vm_inv|

      power_state = nil
      power_state = MiqHypervVm.powerState(vm_inv[:computer_system].EnabledState)

      storage, location = self.vm_inv_to_storage(vm_inv, storage_uids[:storage_id])

      # Collect the reservation information
#      resource_config = vm_inv["resourceConfig"]
#      memory = resource_config["memoryAllocation"]
#      cpu = resource_config["cpuAllocation"]

      host_uuid = vm_inv[:runtime][:settings][:Msvm_ComputerSystem].first.Name

      # Collect the host, storage, and hardware inventory
      hardware = self.vm_inv_to_hardware_hash(vm_inv)
      hardware[:guest_devices], guest_device_uids[mor] = self.vm_inv_to_guest_device_hashes(vm_inv, lan_uids[host_uuid])
#      hardware[:networks] = self.vm_inv_to_network_hashes(vm_inv, guest_device_uids[mor])

      new_result = {
        :uid_ems => mor,
        :name => URI.decode(vm_inv[:display_name].to_s.AsciiToUtf8),
        :vendor => "microsoft",
        :power_state => power_state,
        :location => location,
        :storage => storage,
        :storages => [storage],
        :connection_state => "connected",

#        :standby_action => standby_act,
#        :memory_reserve => memory["reservation"],
#        :memory_reserve_expand => memory["expandableReservation"].to_s.downcase == "true",
#        :memory_limit => memory["limit"],
#        :memory_shares => memory.fetch_path("shares", "shares"),
#        :memory_shares_level => memory.fetch_path("shares", "level"),

#        :cpu_reserve => cpu["reservation"],
#        :cpu_reserve_expand => cpu["expandableReservation"].to_s.downcase == "true",
#        :cpu_limit => cpu["limit"],
#        :cpu_shares => cpu.fetch_path("shares", "shares"),
#        :cpu_shares_level => cpu.fetch_path("shares", "level"),
#        :cpu_affinity => cpu_affinity,

        :host => host_uids[host_uuid],
        :operating_system => self.vm_inv_to_os_hash(vm_inv),
        :hardware => hardware,
        :snapshots => self.vm_inv_to_snapshot_hashes(vm_inv),
      }

      if power_state == 'on'
        vss = vm_inv.fetch_path(:runtime, :settings, :Msvm_VssComponent)
        vss = vss.first unless vss.nil?
        new_result[:tools_status] = vss.StatusDescriptions.first unless vss.nil?
        new_result[:boot_time] = MiqHypervInventory.convert_time(vm_inv[:computer_system].TimeOfLastStateChange)
      end

      result << new_result
      result_uids[mor] = new_result
    end
    return result, result_uids
  end

  def self.vm_inv_to_os_hash(inv)
    inv = inv.fetch_path(:runtime, :guest)
    return nil if inv.blank?

    result = {
      # If the data from VC is empty, default to "Other"
      :name => inv[:FullyQualifiedDomainName],
      :product_name => inv[:OSName].blank? ? "Other" : inv[:OSName],
      :version => "#{inv[:OSMajorVersion]}.#{inv[:OSMinorVersion]}",
      :build_number => inv[:OSBuildNumber],
      :service_pack => inv[:CSDVersion],
    }

    bitness = case inv[:ProcessorArchitecture].to_i
    when 0 then '32'
    when 6,9 then '64'
    else nil
    end
    result[:bitness] = bitness unless bitness.nil?

    return result
  end

  def self.vm_inv_to_hardware_hash(inv)
    result = {}
    guest = inv.fetch_path(:runtime, :guest)

    result[:guest_os_full_name] = result[:guest_os] = guest[:OSName] unless guest.nil?
    result[:bios] = inv[:snapshots][:active].BIOSGUID[1..-2]
    result[:numvcpus] = inv.fetch_path(:config, :settings, :Msvm_ProcessorSettingData).first.VirtualQuantity.to_i
    result[:annotation] = inv[:snapshots][:active].Notes
    result[:memory_cpu] = inv.fetch_path([:config, :settings, :Msvm_MemorySettingData]).first.VirtualQuantity.to_i

    return result
  end

  def self.vm_inv_to_storage(vm_inv, storage_inv)
    cfg_path = URI.encode(File.join(vm_inv[:runtime][:settings][:Msvm_VirtualSystemGlobalSettingData][0].ExternalDataRoot.gsub("\\","/"), "Virtual Machines", "#{vm_inv[:uuid]}.xml"))
    cfg_drive = cfg_path[0,3]
    location = cfg_path[3..-1]
    storage = storage_inv.values.detect {|s| s[:name].include?(cfg_drive)}
    return storage, location
  end

  def self.vm_inv_to_guest_device_hashes(inv, lan_uids)
    inv = inv.fetch_path(:config, :network)

    result = []
    result_uids = {}
    return result, result_uids if inv.blank?

    inv.each do |data|
      #TODO: Flag an error if data is nil.  This means there is a network adapter pointing to
      #      network interface that no longer exists.  The VM will fail during startup.
      next if data.nil?
      uid = address = data[:ethernet_settings].Address
      name = data[:ethernet_settings].ElementName

      lan = lan_uids[data[:Msvm_VirtualSwitch].Name] unless lan_uids.nil? || data[:Msvm_VirtualSwitch].nil?

      new_result = {
        :uid_ems => uid,
        :device_name => name,
        :device_type => 'ethernet',
        :controller_type => 'ethernet',
        :present => true,
        :start_connected => true,
        :address => address,
      }
      new_result[:lan] = lan unless lan.nil?

      result << new_result
      result_uids[uid] = new_result
    end
    return result, result_uids
  end

  def self.vm_inv_to_network_hashes(inv, guest_device_uids)
    inv_guest = inv.fetch_path('summary', 'guest')
    inv = inv.fetch_path('guest', 'net')

    result = []
    return result if inv_guest.nil? || inv.nil?

    hostname = inv_guest['hostName'].blank? ? nil : inv_guest['hostName']
    ipaddress = inv_guest['ipAddress'].blank? ? nil : inv_guest['ipAddress']
    return result if hostname.nil? && ipaddress.nil?

    inv.each do |data|
      ipaddress = (data['ipAddress'].to_miq_a[0].blank?) ? nil : data['ipAddress'][0]
      guest_device = guest_device_uids[data['macAddress']]

      new_result = {
        :hostname => hostname
      }
      new_result[:ipaddress] = ipaddress unless ipaddress.nil?

      result << new_result
      guest_device[:network] = new_result unless guest_device.nil?
    end

    return result
  end

  def self.vm_inv_to_snapshot_hashes(inv)
    result = []
    inv = inv[:snapshots]

    inv[:list].each do |sn|
      parent_uid = sn.Parent.to_s.split(':').last
      parent_uid.chomp!("\"") unless parent_uid.nil?

      uid = sn.InstanceID.split(':').last
      nh = {
        :uid_ems => uid,
        :uid => uid,
        :parent_uid => parent_uid,
        :name => sn.ElementName,
        :description => sn.Notes,
        :create_time => MiqHypervInventory.convert_time(sn.CreationTime),
        :current => sn == inv[:current],
      }
      result << nh
    end
    return result
  end
end
