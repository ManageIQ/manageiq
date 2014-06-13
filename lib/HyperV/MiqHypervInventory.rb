$:.push("#{File.dirname(__FILE__)}")
require 'MiqHypervService'

class MiqHypervInventory < MiqHypervService
  # CIM_ResourceAllocationSettingData - ResourceType defines
  RESOURCE_TYPES = [:none, :other, :computer_system, :processor, :memory, :ide_controller, :parallel_scsi_hba,
    :fc_hba, :iscsi_hba, :ib_hca, :ethernet_adapter, :other_network_adapter, :io_slot, :io_device, :flopyy_drive,
    :cd_drive, :dvd_drive, :serial_port, :parallel_port, :usb_controller, :graphics_controller, :storage_extent,
    :disk, :tape, :other_storage_device, :firewire_controller, :partitionable_unit, :base_partitionable_unit,
    :power_supply, :cooling_device]
    # DMTF RESERVED
    # VENDOR RESERVED 32767..65535

  def initialize(server=nil, username=nil, password=nil)
    super
  end

  def virtualMachines
    return @virtualMachines unless @virtualMachines.blank?
    @virtualMachines = {}
    @wmi.run_query("select * from Msvm_ComputerSystem") do |vm|
      next if vm.Caption.include?("Hosting Computer System")
      # Add name which is a guid as downcase
      @virtualMachines[vm.Name.downcase] = build_vm_hash(vm, false)
    end

    # Use one wmi call to add summary_info for all VMs
    #self.add_summary_to_vm_hash(@virtualMachines)

    #self.dumpHash(@virtualMachines.values[0])
    return @virtualMachines
  end

  def build_vm_hash(vm, summary=false)
    vmh = {:computer_system=>vm, :uuid=>vm.Name, :display_name=>vm.ElementName, :config=>{}, :runtime=>{}}
    config, runtime = vmh[:config], vmh[:runtime]
    config[:settings], config[:devices] = self.config_data(vm)
    runtime[:settings] = self.active_config_data(vm)
    vmh[:snapshots] = self.parse_snapshots(runtime[:settings])
    runtime[:guest] = self.guest_information(runtime[:settings][:Msvm_KvpExchangeComponent].first)
    config[:network] = self.vm_networking(config[:settings])
    vmh[:summary] = self.vm_summary_information(vmh[:snapshots][:active]) unless summary == false
    return vmh
  end

  def hostSystems
    return @hostSystems unless @hostSystems.blank?
    @hostSystems = {}
    @wmi.run_query("select * from Msvm_ComputerSystem where caption = 'Hosting Computer System'") do |host|
      @hostSystems[host.Name] = build_host_hash(host, false)
    end

    #self.dumpHash(@hostSystems.values[0])
    return @hostSystems
  end

  def build_host_hash(host, summary=true)
    hh = {:computer_system=>host, :uuid=>host.Name, :display_name=>host.ElementName, :config=>{}, :runtime=>{}, :storage=>{}}
    config, runtime = hh[:config], hh[:runtime]

    # For data about the host and local storage access the root\cimv2 namespace
    WMIHelper.connectServer(@server, @username, @password) do |wmi_cimv2|
      # Collection local hard drives (3) and network storage (4)
      wmi_cimv2.run_query("select * from Win32_LogicalDisk where DriveType = 3 or DriveType = 4") {|s| hh[:storage]["#{s.SystemName}-#{s.Name[0,1]}"] = s}
      config[:Win32_OperatingSystem] = wmi_cimv2.collect_first("select * from Win32_OperatingSystem")
      config[:Win32_ComputerSystem] = wmi_cimv2.collect_first("select * from Win32_ComputerSystem")
      config[:Win32_Processor] = wmi_cimv2.collect_objects("select * from Win32_Processor")
      config[:Win32_NetworkAdapterConfiguration] = wmi_cimv2.collect_objects('select * from Win32_NetworkAdapterConfiguration where IPEnabled = true')
      config[:Win32_NetworkAdapter] = wmi_cimv2.collect_objects('select * from Win32_NetworkAdapter where PhysicalAdapter = true')
      config[:Win32_Service] = wmi_cimv2.collect_objects("select * from Win32_Service")
    end
    hh[:product] = self.hypervisorVersion
    config[:network] = self.host_networking(config[:Win32_NetworkAdapter])
    runtime[:settings] = self.active_config_data(host)
    return hh
  end

  def host_networking(network_adapters)
    result = []

    # Collect virtual network device configurations
    @wmi.run_query('select * from Msvm_VirtualSwitch') do |vswitch|
      s = {:Msvm_VirtualSwitch => vswitch, :switch_ports=>[]}
      @wmi.collect_associators(vswitch, {:resultClass=>'Msvm_SwitchPort'}) do |sp|
        @wmi.collect_associators(sp, {:resultClass=>'Msvm_SwitchLANEndpoint'}) do |lan|
          h = {sp.Path_.Class.to_sym => sp, lan.Path_.Class.to_sym => lan}
          s[:switch_ports] << h
          @wmi.collect_associators(lan, :resultClass=>'CIM_EthernetPort') do |port|
            h[port.Path_.Class.to_sym] = port
            if port.Path_.Class == "Msvm_ExternalEthernetPort"
              adapter = network_adapters.detect{|a| port.DeviceID == a.GUID}
              h[adapter.Path_.Class.to_sym] = adapter unless adapter.nil?
            end
          end
          @wmi.collect_associators(sp, {:resultClass=>'Msvm_VLANEndpoint'}) do |endpoint|
            @wmi.collect_associators(endpoint, {:resultClass=>'Msvm_VLANEndpointSettingData'}) do |settings|
              h[endpoint.Path_.Class.to_sym] = endpoint
              h[settings.Path_.Class.to_sym] = settings
            end
          end
        end
      end
      result << s
    end
    return result
  end

  def vm_networking(config)
    result = []
    result += vm_networking_hash(config, :Msvm_EmulatedEthernetPortSettingData)
    result += vm_networking_hash(config, :Msvm_SyntheticEthernetPortSettingData)
    return result
  end

  def vm_networking_hash(ethernetPortSettingData, type)
    result = []
    ethernetPortSettingData[type].to_miq_a.each do |e|
      e.Connection.each do |switch_port_path|
        unless switch_port_path.blank?
          h = {:switch_port_path=>switch_port_path, type=>e, :ethernet_settings=>e}
          begin
            switch_port = @wmi.get(switch_port_path)
            h[switch_port.Path_.Class.to_sym] = switch_port
            @wmi.collect_associators(switch_port) {|s| h[s.Path_.Class.to_sym] = s}
            @wmi.collect_associators(h[:Msvm_VLANEndpoint]) {|s| h[s.Path_.Class.to_sym] = s}
          rescue
            # Rescue cases where the get method fails because the switch reference is not valid
            #$log.warn("WMI error while loading instance:[#{switch_port_path}]  Message:[#{$!}]") if $log
          end
        end
        result << h
      end
    end
    return result
  end

  def add_summary_to_vm_hash(vms)
    self.vm_summary_information_multi(vms.values).each do |summ_info|
      vms[summ_info.Name.downcase][:summary] = summ_info
    end
  end

  def refresh_vm(vm)
    return @virtualMachines[vm.Name.downcase] = build_vm_hash(vm)
  end

  def parse_snapshots(cfg_data)
    # The current snapshot references the settings of the last applied snapshot
    # The active snapshot references the current settings being used by the VM.
    snapshots = {:list=> [], :current=>nil, :active=>nil}
    sn_keys = {}
    cfg_data[:Msvm_VirtualSystemSettingData].each do |cfg|
      snapshots[:active] = cfg if cfg.SettingType == 3
      # Type 5 = Snapshot
      if cfg.SettingType == 5
        # All snapshots are added to the list the first time they are referenced.
        # If a snapshot is referenced a second time mark it as the current snapshot.
        if sn_keys.has_key?(cfg.InstanceID)
          snapshots[:current] = sn_keys[cfg.InstanceID] if snapshots[:current].nil?
        else
          snapshots[:list] << sn_keys[cfg.InstanceID] = cfg
        end
      end
    end
    return snapshots
  end

  def snapshots(vm=nil)
    wql = "select * from Msvm_VirtualSystemSettingData where SettingType = 5"
    wql += " AND SystemName = '#{vm.Name}'" unless vm.nil?
    return @wmi.collect_objects(wql)
  end

  def currentSnaptshot(vm, snapshots=nil)
    # Returns an instance of the Msvm_VirtualSystemSettingData
    return @wmi.collect_associators(vm, {:assocClass=>'Msvm_PreviousSettingData'}) {|s| s}.first
  end

  # Handle to active settings for the virtual machine.  The instance itself contains BIOS settings for
  # the VM but more importantly is the parent object that links to the configuration data and devices.
  def current_settings_data(vm)
    return @wmi.collect_first("select * from Msvm_VirtualSystemSettingData where SettingType = 3 AND SystemName = '#{vm.Name}'")
  end

  # SettingData
  def config_data(vm, snapshot=nil)
    ch = Hash.new { |h, k| h[k] = Array.new }
    devices = Hash.new { |h, k| h[k] = Array.new }
    snapshot = current_settings_data(vm) if snapshot.nil?
    @wmi.collect_associators(snapshot, {:assocClass=>'Msvm_VirtualSystemSettingDataComponent'}) {|c| c}.each {|cfg| ch[cfg.Path_.Class.to_sym] << cfg}

    # Break devices up by resource type
    ch[:Msvm_ResourceAllocationSettingData].each {|d| devices[RESOURCE_TYPES[d.ResourceType]] << d}
    return ch, devices
  end

  # Returns WMI association classes to MSVM_ComputerSystem object.  Includes addition classes when the VM is running.
  def active_config_data(vm)
    ch = Hash.new { |h, k| h[k] = Array.new }
    @wmi.collect_associators(vm) {|c| c}.each {|cfg| ch[cfg.Path_.Class.to_sym] << cfg}
    return ch
  end

  def vm_summary_information(vm, settingData=nil)
    return vm_summary_information_multi([vm]).first
  end

  def vm_summary_information_multi(vm_list, add_req_values=[])
    return [] if vm_list.blank?
    
    # Allow method to be called with a vm hash structure or the specific Msvm_VirtualSystemSettingData object
    vm_list = vm_list.collect {|vmh| vmh[:snapshots][:active]} if vm_list.first.class == Hash
    settingData = vm_list.collect {|sd| sd.Path_.Path}
    # Full "RequestedInformation" values defined on the GetSummaryInformation Method of the Msvm_VirtualSystemManagementService Class
    # List of currently available, but excluded values:
    # 2   - Creation Time
    # 3   - Notes
    # 4   - Number of Processors
    # 5   - Small Thumbnail Image (80x60), 6 - MediumThumbnailImage (160x120), 7 - LargeThumbnailImage (320x240)
    # 100 - EnabledState
    # 107 - Snapshots
    # 108 - AsynchronousTasks
    requestedInformation = [0,1,101,102,103,104,105,106,109,110,111] + add_req_values
    rc, obj, job = self.wmi_update_system('GetSummaryInformation', {'SettingData'=>settingData, 'RequestedInformation'=>requestedInformation})
    return obj.SummaryInformation
  end

  def guest_information(kvp)
    return nil if kvp.nil? || kvp.GuestIntrinsicExchangeItems.nil?
    guestHash = {}
    kvp.GuestIntrinsicExchangeItems.each do |xml_str|
      dh = self.parse_kvp_xml(xml_str)
      guestHash[dh['Name'].to_sym] = dh['Data']
    end
    return guestHash
  end

  def parse_kvp_xml(xml_str)
    xml = MiqXml.load(xml_str)
    hsh = {}

    xml.root.each_element do |e|
      if e.has_elements?
        hsh[e.attributes['NAME']] = e.elements['VALUE'].text
        hsh[e.attributes['NAME']] = hsh[e.attributes['NAME']].to_i if e.attributes['TYPE'].include?('int')
      end
    end
    return hsh
  end

  def hypervisorVersion()
    verHash = nil
    begin
      WMIHelper.connectServer(@server, @username, @password) do |wmi_cimv2|
        vmms = wmi_cimv2.collect_first("select * from Win32_Service where PathName like '%vmms.exe%'")
        return nil if vmms.blank?
        # Double up path separators for the CIM_DataFile query
        hyperv_file = vmms.PathName.gsub('\\') {'\\\\'}
        va = wmi_cimv2.collect("select * from CIM_DataFile where name = '#{hyperv_file}'") {|f| f.Version}.first
        va = va.split('.')
        verHash = {"vendor"=>"Microsoft", "product"=>vmms.DisplayName, "version"=>va[0..2].join('.'), "build"=>va[-1]} unless va.nil?
      end
    rescue
    end
    return verHash
  end

  def registeredVms()
    pathHash = {}
    vms = []
    @wmi.run_query("select * from Msvm_VirtualSystemGlobalSettingData") do |vm|
      pathHash[vm.InstanceID] = vm.ExternalDataRoot
    end

    @wmi.run_query("select * from Msvm_ComputerSystem") do |vm|
      next if vm.caption.include?("Hosting")
      k,v = pathHash.detect {|k,v| k.include?(vm.Name)}

      vmPath = File.join(v.gsub("\\",'/'), 'Virtual Machines', vm.Name + ".xml")
      vms << vmPath if File.exist?(vmPath)
    end
    return vms
  end

  def ems_refresh()
    inv = {:host => self.hostSystems, :vm =>self.virtualMachines}

    # Since HyperV is only a single host, get the storage items and move them to the root
    inv[:storage] = inv[:host].values.first[:storage]

    # Write data out to a file for easy searching
    #File.open("d:/temp/HyperV/hyperv-all.txt", 'w') {|f| dumpObj(inv, nil, f, :write)}
    #inv.each {|type, hash| hash.each {|k,v| File.open("d:/temp/HyperV/#{type}-#{k}.txt", 'w') {|f| dumpObj(v, nil, f, :write)}}}
    
    return inv
  end

  def self.convert_time(ts)
    return nil if ts.nil?
    return Time.utc($1, $2, $3, $4, $5, $6, $7) if ts =~ /([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})\.([0-9]{6})\-([0-9]{3})/
  end

	##########################
	# Object utility methods.
	##########################

	#
	# When used in the broker - DRB - this method is redefined
	# to carry the cacheLock into the DRB dump method.
	#
	# When not used in the broker, there is no need to copy the object.
	#
	def dupObj(obj)
    obj
  end

	#
	# When used in the broker - DRB - this method is redefined
	# to create a deep clone of the object.
	#
	def conditionalCopy(obj)
		obj
	end
end
