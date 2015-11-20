module ManageIQ::Providers::Vmware::InfraManager::VmOrTemplateShared::Scanning
  def perform_metadata_scan(ost)
    require 'MiqVm/MiqVm'

    log_pref = "MIQ(#{self.class.name}##{__method__})"
    vm_name  = File.uri_to_local_path(ost.args[0])
    $log.debug "#{log_pref} VM = #{vm_name}"

    args1 = ost.args[1]
    args1['ems'][:use_vim_broker]      = MiqServer.use_broker_for_embedded_proxy?(args1['ems']['connect_to'])
    args1['ems'][:vim_broker_drb_port] = MiqVimBrokerWorker.drb_port if args1['ems'][:use_vim_broker]

    begin
      @vm_cfg_file = vm_name
      connect_to_ems(ost)
      ost.force = !self.template?
      miq_vm = MiqVm.new(@vm_cfg_file, ost) # TODO: Create VMware-specific MiqVm subclass
      scan_via_miq_vm(miq_vm, ost)
    rescue => err
      $log.error "#{log_pref}: #{err}"
      $log.debug err.backtrace.join("\n")
      raise
    ensure
      miq_vm.unmount if miq_vm
    end
  end

  def perform_metadata_sync(ost)
    sync_stashed_metadata(ost)
  end

  def validate_smartstate_analysis
    validate_supported_check("Smartstate Analysis")
  end

  private

  # Moved from MIQExtract.rb
  def connect_to_ems(ost)
    $log.debug "connect_to_ems: ost.config && ost.config.capabilities[:vixDisk] = #{(ost.config && ost.config.capabilities[:vixDisk]).class.name}"
    if ost.config && ost.config.capabilities[:vixDisk] == true
      # Make sure we were given a ems/host to connect to
      ems_connect_type = ost.scanData.fetch_path('ems', 'connect_to') || 'host'
      $log.debug "connect_to_ems: ems_connect_type = #{ems_connect_type}"
      miqVimHost = ost.scanData.fetch_path("ems", ems_connect_type) # XXX What is this???
      $log.debug "connect_to_ems: miqVimHost = #{miqVimHost.class.name}"
      if miqVimHost
        st = Time.now
        use_broker = ost.scanData["ems"][:use_vim_broker] == true
        miqVimHost[:address] = miqVimHost[:ipaddress] if miqVimHost[:address].nil?
        ems_display_text = "#{ems_connect_type}(#{use_broker ? 'via broker' : 'directly'}):#{miqVimHost[:address]}"
        $log.info "Connecting to [#{ems_display_text}] for VM:[#{@vmCfgFile}]"
        password_decrypt = MiqPassword.decrypt(miqVimHost[:password])
        if !$miqHostCfg || !$miqHostCfg.emsLocal
          ($miqHostCfg ||= OpenStruct.new).vimHost = ost.scanData["ems"]['host']
          $miqHostCfg.vimHost[:use_vim_broker] = use_broker
        end

        begin
          require 'miq_fault_tolerant_vim'
          # TODO: Should this move to the EMS?
          ost.miqVim = MiqFaultTolerantVim.new(:ip => miqVimHost[:address], :user => miqVimHost[:username], :pass => password_decrypt, :use_broker => use_broker, :vim_broker_drb_port => ost.scanData['ems'][:vim_broker_drb_port])
          # ost.snapId = opts.snapId if opts.snapId
          $log.info "Connection to [#{ems_display_text}] completed for VM:[#{@vmCfgFile}] in [#{Time.now - st}] seconds"
        rescue Timeout::Error => err
          msg = "Connection to [#{ems_display_text}] timed out for VM:[#{@vmCfgFile}] with error [#{err}] after [#{Time.now - st}] seconds"
          $log.error msg
          raise err, msg, err.backtrace
        rescue Exception => err
          msg = "Connection to [#{ems_display_text}] failed for VM:[#{@vmCfgFile}] with error [#{err}] after [#{Time.now - st}] seconds"
          $log.error msg
          raise err, msg, err.backtrace
        end
      end
    end
  end
end
