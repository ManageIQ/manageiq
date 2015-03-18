module MiqProvisionVmware::Customization
  def build_customization_spec
    log_header = "MIQ(#{self.class.name}#build_customization_spec)"

    sysprep_option = get_option(:sysprep_enabled)
    if sysprep_option.blank? || sysprep_option == 'disabled'
      $log.warn "#{log_header} VM Customization will be skipped.  Sysprep customization option set to [#{sysprep_option}]"
      return nil
    end
    $log.info "#{log_header} Sysprep customization option set to [#{sysprep_option}]"

    # If an existing VC customization spec was selected connect to VC and get the spec
    custom_spec_name = get_option(:sysprep_custom_spec).to_s.strip
    sysprep_spec_override = get_option(:sysprep_spec_override)
    spec = load_customization_spec(custom_spec_name)
    spec = spec.spec unless spec.nil?
    $log.info "#{log_header} Loaded custom spec [#{custom_spec_name}].  Override flag: [#{sysprep_spec_override}]"
    if sysprep_spec_override == false
      adjust_nicSettingMap(spec)
      return spec
    end

    spec = VimHash.new("CustomizationSpec") if spec.nil?

    # Create customization spec based on platform
    case self.source.platform
    when 'linux', 'windows'
      identity = self.send("customization_identity_#{self.source.platform}", spec)
      return if identity.nil?
      spec.identity = identity
    else
      $log.warn "#{log_header} VM Customization will be skipped.  Not supported for platform type [#{self.source.platform}]"
      return
    end

    globalIPSettings = find_build_spec_path(spec, 'CustomizationGlobalIPSettings', 'globalIPSettings')
    # In Linux, DNS server settings are global.  In Windows, these settings are adapter-specific
    set_spec_array_option(globalIPSettings, :dnsServerList, :dns_servers)  if self.source.platform == "linux"
    set_spec_array_option(globalIPSettings, :dnsSuffixList, :dns_suffixes)

    customization_nicSettingMap(self.source.platform, spec)

    if self.source.platform == "windows"
      options = find_build_spec_path(spec, 'CustomizationWinOptions', 'options')
      set_spec_option(options, :changeSID, :sysprep_change_sid)
      # From: What's New in the VI SDK 2.5?
      # Deleting user accounts as part of a customization routine is not supported as of VI API 2.5: the
      # deleteAccounts property is ignored.
      set_spec_option(options, :deleteAccounts, :sysprep_delete_accounts)
    end

    return spec
  end

  def customization_identity_windows(spec)
    log_header = "MIQ(#{self.class.name}.customization_identity_windows)"
    sysprep_option = get_option(:sysprep_enabled)

    identity = nil
    if sysprep_option == 'file'
      identity = VimHash.new("CustomizationSysprepText") do |sysprep|
        $log.info "#{log_header} Sysprep Text being set from file"
        sysprep.value = get_option(:sysprep_upload_text)
      end
    else
      identity = find_build_spec_path(spec, 'CustomizationSysprep', 'identity')
      guiUnattended = find_build_spec_path(identity, 'CustomizationGuiUnattended', 'guiUnattended')
      set_spec_option(guiUnattended, :autoLogon, :sysprep_auto_logon)
      set_spec_option(guiUnattended, :autoLogonCount, :sysprep_auto_logon_count, 1, :to_i)
      set_spec_option(guiUnattended, :timeZone, :sysprep_timezone)

      # From: What's New in the VI SDK 2.5?
      # To change the administrator password, set the administrator password to blank in the master VM.
      # Sysprep will then be able to change the password to the one specified by the password.
      set_spec_password_option(guiUnattended, :password, :sysprep_password, "new administrator")

      identification = find_build_spec_path(identity, 'CustomizationIdentification', 'identification')
      if get_option(:sysprep_identification) == 'workgroup'
        identification.delete('joinDomain')
        identification.delete('domainAdmin')
        set_spec_option(identification, :joinWorkgroup, :sysprep_workgroup_name)
      else
        identification.delete('joinWorkgroup')
        set_spec_option(identification, :joinDomain, :sysprep_domain_name)
        set_spec_option(identification, :domainAdmin, :sysprep_domain_admin)
        set_spec_password_option(identification, :domainAdminPassword, :sysprep_domain_password, "domain administrator")
      end

      licenseFilePrintData = find_build_spec_path(identity, 'CustomizationLicenseFilePrintData', 'licenseFilePrintData')
      svr_license = get_option(:sysprep_server_license_mode)
      licenseFilePrintData.autoMode = VimString.new(svr_license, "CustomizationLicenseDataMode")
      set_spec_option(licenseFilePrintData, :autoUsers, :sysprep_per_server_max_connections, nil, :to_i)

      userData = find_build_spec_path(identity, 'CustomizationUserData', 'userData')
      set_spec_option(userData, :fullName, :sysprep_full_name)
      set_spec_option(userData, :orgName, :sysprep_organization)
      set_spec_option(userData, :productId, :sysprep_product_id)
      userData.computerName = customization_hostname()
    end
    return identity
  end

  def customization_identity_linux(spec)
    log_header = "MIQ(#{self.class.name}.customization_identity_linux)"
    identity = find_build_spec_path(spec, 'CustomizationLinuxPrep', 'identity')
    set_spec_option(identity, :domain, :linux_domain_name)
    identity.hostName = customization_hostname()
    return identity
  end

  def collect_nic_settings
    nics = self.options[:nic_settings].to_miq_a
    nic = nics[0]
    nic = {} if nic.blank?
    [:dns_domain, :dns_servers, :sysprep_netbios_mode, :wins_servers, :addr_mode,
     :gateway, :subnet_mask, :ip_addr].each {|key| nic[key] = self.options[key]}
    nics[0] = nic

    self.options[:nic_settings]   = nics
    self.update_attribute(:options, self.options)
    nics
  end

  def customization_nicSettingMap(source_platform, spec)
    log_header = "MIQ(#{self.class.name}.customization_nicSettingMap)"
    nic_settings = self.collect_nic_settings

    spec.nicSettingMap ||= VimArray.new("ArrayOfCustomizationAdapterMapping")

    requested_network_adapter_count = self.options[:requested_network_adapter_count].to_i

    nic_settings.each_with_index do |nic, idx|

      break if idx >= requested_network_adapter_count
      $log.warn "#{log_header} Nic index:<#{idx}> -- settings:<#{nic.inspect}>"
      spec.nicSettingMap[idx] = VimHash.new("CustomizationAdapterMapping") if spec.nicSettingMap[idx].blank?
      adap_map = spec.nicSettingMap[idx]
      adapter = find_build_spec_path(adap_map, 'CustomizationIPSettings', 'adapter')

      set_spec_option(adapter, :dnsDomain, nil, nil, nil, nic[:dns_domain])
      # In Windows, the DNS Server list is adapter-specific, whereas in Linux, it is global.
      if source_platform == "windows"
        set_spec_array_option(adapter, :dnsServerList, nil, nic[:dns_servers])

        netbios = get_option(nil, nic[:sysprep_netbios_mode])
        adapter.netBIOS = VimString.new(netbios, "CustomizationNetBIOSMode") unless netbios.blank?
      end

      wins_server = get_option(nil, nic[:wins_servers]).to_s.split(',')
      set_spec_option(adapter, :primaryWINS,   nil, nil, nil, wins_server[0])
      set_spec_option(adapter, :secondaryWINS, nil, nil, nil, wins_server[1])

      if get_option(nil, nic[:addr_mode]) == "dhcp"
        $log.info "#{log_header} Using DHCP IP settings"
        adapter.ip = VimHash.new("CustomizationDhcpIpGenerator")
        adapter.delete('gateway')
        adapter.delete('subnetMask')
      else
        set_spec_array_option(adapter, :gateway, nil, nic[:gateway])
        set_spec_option(adapter, :subnetMask, nil, nil, nil, nic[:subnet_mask])
        adapter.ip = VimHash.new("CustomizationFixedIp") do |fixed_ip|
          ip_address = get_option(nil, nic[:ip_addr])
          $log.info "#{log_header} Using Fixed IP address [#{ip_address}]"
          fixed_ip.ipAddress = ip_address
        end
      end
    end

    adjust_nicSettingMap(spec)
  end

  # NicSettings much match the number of network adapters being passed in the config spec
  def adjust_nicSettingMap(spec)
    return if spec.blank?

    requested_network_adapter_count = self.options[:requested_network_adapter_count].to_i
    nic_count = spec.nicSettingMap.to_miq_a.length

    if requested_network_adapter_count < nic_count
      # Remove nicSettings to match network adapter count
      nic_count.downto(requested_network_adapter_count + 1) {spec.nicSettingMap.pop}
    elsif requested_network_adapter_count > nic_count
      # Add DHCP nicSettings to match network adapter count
      spec.nicSettingMap ||= VimArray.new("ArrayOfCustomizationAdapterMapping")
      nic_count.upto(requested_network_adapter_count - 1) do
        adapter_map = VimHash.new("CustomizationAdapterMapping")
        adapter = find_build_spec_path(adapter_map, 'CustomizationIPSettings', 'adapter')
        adapter.ip = VimHash.new("CustomizationDhcpIpGenerator")
        spec.nicSettingMap << adapter_map
      end
    end
  end

  def validate_customization_spec(custom_spec)
    return if custom_spec.nil?
    return if custom_spec['nicSettingMap'].blank?

    custom_spec['nicSettingMap'].each do |nic|
      # From VI API: CustomizationUnknownIpGenerator - "The IP address is left unspecified. The user must be prompted to supply an IP address."
      ip_data_type = nic['adapter']['ip'].xsiType rescue nil
      raise MiqException::MiqProvisionError, "Unsupported Customization Spec option detected: Prompt the user for an IP address" if ip_data_type == 'CustomizationUnknownIpGenerator'
    end
  end

  def load_customization_spec(custom_spec_name)
    log_header = "MIQ(#{self.class.name}.load_customization_spec)"
    custom_spec_name = nil if custom_spec_name == "__VC__NONE__"
    unless custom_spec_name.blank?
      $log.info "#{log_header} Using customization spec [#{custom_spec_name}]"
      cs = self.source.ext_management_system.customization_specs.find_by_id(custom_spec_name)
      cs = self.source.ext_management_system.customization_specs.find_by_name(custom_spec_name) if cs.nil?
      raise MiqException::MiqProvisionError, "Customization Specification [#{custom_spec_name}] does not exist." if cs.nil?
      raise MiqException::MiqProvisionError, "Customization Specification [#{custom_spec_name}] for OS type [#{cs[:typ]}] does not match the template VM OS" if cs[:typ].downcase != self.source.platform
      $log.info "#{log_header} Using customization spec [#{cs.name}]"
      return cs
    else
      $log.info "#{log_header} Customization spec name is empty, no spec will be loaded."
      return nil
    end
  end

  def find_build_spec_path(spec, end_type, *path)
    found = spec.fetch_path(path)
    if found.nil?
      new_path = path.pop
      parent = path.blank? ? spec : spec.fetch_path(path)
      found = parent[new_path.to_s] = VimHash.new(end_type)
    end
    return found
  end

  def customization_hostname()
    log_header = "MIQ(#{self.class.name}.customization_hostname)"
    VimHash.new("CustomizationFixedName") do |mach_name|
      computer_name = get_option(:vm_target_hostname)
      computer_name = hostname_cleanup(computer_name)
      $log.info "#{log_header} CustomizationFixedName was set to #{computer_name}(#{computer_name.class})"
      mach_name.name = computer_name
    end
  end

  def set_spec_password_option(obj, property, key, pwd_type)
    log_header = "#{self.class.name}.set_spec_password_option"

    value = get_option(key).to_s.strip
    value = MiqPassword.try_decrypt(value)
    unless value.blank?
      pwd_hash = VimHash.new("CustomizationPassword") do |cust_pass|
        cust_pass.plainText = "true"
        cust_pass.value     = value
        $log.info "#{log_header} #{pwd_type} password was set [#{"*" * value.length}]"
      end
      obj.send("#{property}=", pwd_hash)
    else
      value = obj.send("#{property}")
      if value.nil?
        $log.info "#{log_header} #{pwd_type} password was NOT set"
      else
        $log.info "#{log_header} #{pwd_type} password inheriting value from spec"
      end
    end
  end

  def set_spec_array_option(obj, property, key, override_value=nil)
    log_header = "#{self.class.name}.set_spec_array_option"
    if key.nil?
      value = get_option(nil, override_value)
    else
      value = override_value.nil? ? get_option(key) : override_value
    end
    values = value.to_s.split(",")
    unless values.blank?
      value = VimArray.new {|l| values.each {|i| l << i.strip}}
      $log.info "#{log_header} #{property} was set to #{value.inspect} (#{value.class})"
      obj.send("#{property}=", value)
    else
      $log.info "#{log_header} #{property} was NOT set due to blank values"
    end
  end
end
