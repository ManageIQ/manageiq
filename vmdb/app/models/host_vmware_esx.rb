class HostVmwareEsx < HostVmware
  def self.use_vim_broker?
    false
  end

  def use_vim_broker?
    self.class.use_vim_broker?
  end

  def vim_shutdown(force = false)
    with_provider_object do |vim_host|
      $log.info "MIQ(Host.vim_shutdown) Invoking with: force: [#{force}]"
      vim_host.shutdownHost(force)
    end
  end

  def vim_reboot(force = false)
    with_provider_object do |vim_host|
      $log.info "MIQ(Host.vim_reboot) Invoking with: force: [#{force}]"
      vim_host.rebootHost(force)
    end
  end

  def vim_enter_maintenance_mode(timeout = 0, evacuate_powered_off_vms = false)
    with_provider_object do |vim_host|
      $log.info "MIQ(Host.vim_enter_maintenance_mode) Invoking with: timeout: [#{timeout}], evacuate_powered_off_vms: [#{evacuate_powered_off_vms}]"
      vim_host.enterMaintenanceMode(timeout, evacuate_powered_off_vms)
    end
  end

  def vim_exit_maintenance_mode(timeout = 0)
    with_provider_object do |vim_host|
      $log.info "MIQ(Host.vim_exit_maintenance_mode) Invoking with: timeout: [#{timeout}]"
      vim_host.exitMaintenanceMode(timeout)
    end
  end

  def vim_in_maintenance_mode?
    with_provider_object do |vim_host|
      $log.info "MIQ(Host.vim_in_maintenance_mode?) Invoking"
      vim_host.inMaintenanceMode?
    end
  end

  def vim_power_down_to_standby(timeout = 0, evacuate_powered_off_vms = false)
    with_provider_object do |vim_host|
      $log.info "MIQ(Host.vim_power_down_to_standby) Invoking with: timeout: [#{timeout}], evacuate_powered_off_vms: [#{evacuate_powered_off_vms}]"
      vim_host.powerDownHostToStandBy(timeout, evacuate_powered_off_vms)
    end
  end

  def vim_power_up_from_standby(timeout = 0)
    with_provider_object do |vim_host|
      $log.info "MIQ(Host.vim_power_up_from_standby) Invoking with: timeout: [#{timeout}]"
      vim_host.powerUpHostFromStandBy(timeout)
    end
  end

  def vim_vmotion_enabled?(device = nil)
    with_provider_object do |vim_host|
      vnm      = vim_host.hostVirtualNicManager
      selected = vnm.selectedVnicsByType("vmotion")
      selected = selected.select { |vnic| vnic.device == device } unless device.nil?
      return !selected.empty?
    end
  end

  def vim_enable_vmotion(device = nil)
    with_provider_object do |vim_host|
      vnm      = vim_host.hostVirtualNicManager
      device ||= vnm.candidateVnicsByType("vmotion").first.device rescue nil
      $log.info "MIQ(Host.vim_enable_vmotion) Invoking for device=<#{device}>"
      vnm.selectVnicForNicType("vmotion", device) unless device.nil?
    end
  end

  def vim_disable_vmotion(device = nil)
    with_provider_object do |vim_host|
      vnm      = vim_host.hostVirtualNicManager
      device ||= vnm.candidateVnicsByType("vmotion").first.device rescue nil
      $log.info "MIQ(Host.vim_disable_vmotion) Invoking for device=<#{device}>"
      vnm.deselectVnicForNicType("vmotion", device) unless device.nil?
    end
  end

  def vim_firewall_rules
    data = {'config' => {}}
    with_provider_object do |vim_host|
      fws = vim_host.firewallSystem
      return [] if fws.nil?
      data['config']['firewall'] = fws.firewallInfo
    end

    EmsRefresh::Parsers::Vc.host_inv_to_firewall_rules_hashes(data)
  end

  def vim_advanced_settings
    data = {'config' => {}}
    with_provider_object do |vim_host|
      aom = vim_host.advancedOptionManager
      return nil if aom.nil?
      data['config']['option'] = aom.setting
      data['config']['optionDef'] = aom.supportedOption
    end

    EmsRefresh::Parsers::Vc.host_inv_to_advanced_settings_hashes(data)
  end

  def verify_credentials_with_ws(auth_type=nil)
    raise "No credentials defined" if self.authentication_invalid?(auth_type)

    begin
      with_provider_connection(:use_broker => false, :auth_type => auth_type) {}
    rescue SocketError, Errno::EHOSTUNREACH, Errno::ENETUNREACH
      raise MiqException::MiqUnreachableError, $!.message
    rescue Handsoap::Fault
      $log.warn("MIQ(Host-verify_credentials_with_ws): #{$!.inspect}")
      if $!.respond_to?(:reason)
        raise MiqException::MiqInvalidCredentialsError, $!.reason if $!.reason =~ /Authorize Exception|incorrect user name or password/
        raise $!.reason
      end
      raise $!.message
    rescue Exception
      $log.warn("MIQ(Host-verify_credentials_with_ws): #{$!.inspect}")
      raise "Unexpected response returned from system, see log for details"
    else
      true
    end
  end

  def refresh_logs
    if self.authentication_invalid?
      $log.warn "MIQ(Host.refresh_logs) No credentials defined for Host [#{self.name}]"
      return
    end

    begin
      vim = self.connect
      unless vim.nil?
        sp = HostScanProfiles.new(ScanItem.get_profile("host default"))
        hashes = sp.parse_data_hostd(vim)
        EventLog.add_elements(self, hashes)
      end
    rescue
      $log.log_backtrace($!)
    rescue MiqException::MiqVimBrokerUnavailable => err
      MiqVimBrokerWorker.broker_unavailable(err.class.name,  err.to_s)
      $log.warn("MIQ(Host.refresh_logs) Reported the broker unavailable")
    rescue TimeoutError
      $log.warn "(Host.refresh_logs) Timeout encountered during log collection for Host [#{self.name}]"
    ensure
      vim.disconnect rescue nil
    end
  end

  def refresh_firewall_rules
    return if self.ext_management_system.nil? || self.operating_system.nil?

    fwh = self.vim_firewall_rules
    unless fwh.nil?
      FirewallRule.add_elements(self, fwh)
      self.operating_system.save unless self.operating_system.nil?
    end
  end

  def refresh_advanced_settings
    return if self.ext_management_system.nil?

    ash = self.vim_advanced_settings
    AdvancedSetting.add_elements(self, ash) unless ash.nil?
  end

end
