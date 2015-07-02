module ManageIQ::Providers::Vmware::InfraManager::Provision::Configuration::Network
  def build_config_network_adapters(vmcs)
    requested_networks = normalize_network_adapter_settings
    template_networks  = get_network_adapters

    if requested_networks.blank?
      options[:requested_network_adapter_count] = template_networks.length
      _log.warn "VLan options is nil.  VLan settings will be inherited from the template."
    else
      options[:requested_network_adapter_count] = requested_networks.length
      requested_networks.each_with_index do |net, idx|
        vim_net_adapter = template_networks[idx]

        if net[:is_dvs] == true
          build_config_spec_dvs(net, vim_net_adapter, vmcs)
        else
          build_config_spec_vlan(net, vim_net_adapter, vmcs)
        end
      end

      # Remove any unneeded template networks
      # Use .to_miq_a to handle cases where more networks are requested then exist on the source VM
      # in which case the array [length..-1] logic will return nil.  (So please do not remove it...again.)
      template_networks[requested_networks.length..-1].to_miq_a.each do |vim_net_adapter|
        build_config_spec_delete_existing_vlan(vmcs, vim_net_adapter)
      end
    end
  end

  def normalize_network_adapter_settings
    if options[:networks].blank?
      vlan = get_option(:vlan)
      _log.info("vlan: #{vlan.inspect}")
      unless vlan.nil?
        options[:networks] = [] << net = {:network => vlan, :mac_address => get_option_last(:mac_address)}
        if vlan[0, 4] == 'dvs_'
          # Remove the "dvs_" prefix on the name
          net[:network] = vlan[4..-1]
          net[:is_dvs]  = true
        end
      end
    else
      # When using advanced network settings update the options hash to reflect the selected vlan
      net = options[:networks].first
      options[:vlan] = [net[:is_dvs] == true ? "dvs_#{net[:network]}" : net[:network], net[:network]]
    end
    options[:networks]
  end

  def build_config_spec_vlan(network, vnicDev, vmcs)
    operation = vnicDev.nil? ? VirtualDeviceConfigSpecOperation::Add : VirtualDeviceConfigSpecOperation::Edit
    add_device_config_spec(vmcs, operation) do |vdcs|
      vdcs.device = vnicDev || create_vlan_device(network)
      _log.info "Setting target network device to Device Name:<#{network[:network]}>  Device:<#{vdcs.device.inspect}>"
      vdcs.device.backing.deviceName = network[:network]
      #
      # Manually assign MAC address to target VM.
      #
      mac_addr = network[:mac_address]
      unless mac_addr.blank?
        vdcs.device.macAddress = mac_addr
        vdcs.device.addressType = 'Manual'
      end
    end
  end

  def build_config_spec_dvs(network, vnicDev, vmcs)
    source.with_provider_connection do |vim|
      operation = vnicDev.nil? ? VirtualDeviceConfigSpecOperation::Add : VirtualDeviceConfigSpecOperation::Edit
      add_device_config_spec(vmcs, operation) do |vdcs|
        vdcs.device = vnicDev || create_vlan_device(network)
        _log.info "Setting target network device to Device Name:<#{network[:network]}>  Device:<#{vdcs.device.inspect}>"

        #
        # Change the port group of the target VM.
        #

        vdcs.device.backing = VimHash.new('VirtualEthernetCardDistributedVirtualPortBackingInfo') do |vecdvpbi|
          vecdvpbi.port = VimHash.new('DistributedVirtualSwitchPortConnection') do |dvspc|
            #
            # Get the DVS info for a given host.
            #
            dvs = vim.queryDvsConfigTarget(vim.sic.dvSwitchManager, dest_host.ems_ref_obj, nil)
            dpg = vim.applyFilter(dvs.distributedVirtualPortgroup, 'uplinkPortgroup' => 'false').detect { |nupg| URI.decode(nupg.portgroupName) == network[:network] }

            raise MiqException::MiqProvisionError, "Port group [#{network[:network]}] is not available on target host [#{dest_host.name}]" if dpg.nil?
            _log.info("portgroupName: #{dpg.portgroupName}, portgroupKey: #{dpg.portgroupKey}, switchUuid: #{dpg.switchUuid}")

            dvspc.switchUuid   = dpg.switchUuid
            dvspc.portgroupKey = dpg.portgroupKey
          end
        end

        #
        # Manually assign MAC address to target VM.
        #
        mac_addr = network[:mac_address]
        unless mac_addr.blank?
          vdcs.device.macAddress = mac_addr
          vdcs.device.addressType = 'Manual'
        end
      end
    end
  end

  def create_vlan_device(network)
    device_type = get_config_spec_value(network, 'VirtualPCNet32', nil, [:devicetype])
    VimHash.new(device_type) do |vDev|
      vDev.key = get_next_device_idx
      vDev.connectable = VimHash.new('VirtualDeviceConnectInfo') do |con|
        con.allowGuestControl = get_config_spec_value(network, 'true', nil, [:connectable, :allowguestcontrol])
        con.startConnected    = get_config_spec_value(network, 'true', nil, [:connectable, :startconnected])
        con.connected         = get_config_spec_value(network, 'true', nil, [:connectable, :connected])
      end
      vDev.backing = VimHash.new('VirtualEthernetCardNetworkBackingInfo') do |bck|
        bck.deviceName = network[:network]
      end
    end
  end

  def find_dvs_by_name(vim, dvs_name)
    dvs = vim.queryDvsConfigTarget(vim.sic.dvSwitchManager, dest_host.ems_ref_obj, nil) rescue nil
    # List the names of the non-uplink portgroups.
    unless dvs.nil? || dvs.distributedVirtualPortgroup.nil?
      return vim.applyFilter(dvs.distributedVirtualPortgroup, 'portgroupName' => dvs_name, 'uplinkPortgroup' => 'false').first
    end
    nil
  end

  def build_config_spec_delete_existing_vlan(vmcs, net_device)
    add_device_config_spec(vmcs, VirtualDeviceConfigSpecOperation::Remove) do |vdcs|
      _log.info "Deleting network device with Device Name:<#{net_device.fetch_path('deviceInfo', 'label')}>"
      vdcs.device    = net_device
    end
  end

  def get_network_adapters
    inventory_hash = source.with_provider_connection do |vim|
      vim.virtualMachineByMor(source.ems_ref_obj)
    end

    devs = inventory_hash.fetch_path("config", "hardware", "device") || []
    devs.select { |d| d.key?('macAddress') }.sort_by { |d| d['unitNumber'] }
  end

  def get_network_device(vimVm, _vmcs, _vim = nil, vlan = nil)
    svm = source
    nic = svm.hardware.nil? ? nil : svm.hardware.nics.first
    unless nic.nil?
      # if passed a vlan, validate that the target host supports it.
      unless vlan.nil?
        raise MiqException::MiqProvisionError, "vLan [#{vlan}] is not available on target host [#{dest_host.name}]" unless dest_host.lans.any? { |l| l.name == vlan }
      end

      vnicDev = vimVm.devicesByFilter('deviceInfo.label' => nic.device_name).first
      raise MiqException::MiqProvisionError, "Target network device <#{nic.device_name}> was not found." if vnicDev.nil?
      return vnicDev
    else
      if svm.hardware.nil?
        raise MiqException::MiqProvisionError, "Source template does not have a connection to the hardware table."
      else
        raise MiqException::MiqProvisionError, "Source template does not have a nic defined."
      end
    end
  end
end
