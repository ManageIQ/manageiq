module ManageIQ::Providers::Redhat::InfraManager::VmOrTemplateShared::Scanning
  def perform_metadata_scan(ost)
    require 'MiqVm/MiqRhevmVm'

    log_pref = "MIQ(#{self.class.name}##{__method__})"
    vm_name  = File.uri_to_local_path(ost.args[0])
    $log.debug "#{log_pref} VM = #{vm_name}"

    args1 = ost.args[1]
    args1['ems']['connect'] = true if args1[:mount].blank?

    begin
      $log.debug "perform_metadata_scan: vm_name = #{vm_name}"
      @vm_cfg_file = vm_name
      connect_to_ems(ost)
      miq_vm = MiqRhevmVm.new(@vm_cfg_file, ost)
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

  private

  # Moved from MIQExtract.rb
  # TODO: Should this be in the ems?
  def connect_to_ems(ost)
    log_header = "MIQ(#{self.class.name}.#{__method__})"

    # Check if we've been told explicitly not to connect to the ems
    # TODO: See vm_scan.rb: config_ems_list() - is this always false for RedHat?
    if ost.scanData.fetch_path("ems", 'connect') == false
      $log.debug "#{log_header}: returning, ems/connect == false"
      return
    end

    # Make sure we were given a ems/host to connect to
    ems_connect_type = ost.scanData.fetch_path('ems', 'connect_to') || 'host'
    miqVimHost = ost.scanData.fetch_path("ems", ems_connect_type)
    if miqVimHost
      st = Time.now
      use_broker = false
      miqVimHost[:address] = miqVimHost[:ipaddress] if miqVimHost[:address].nil?
      ems_display_text = "#{ems_connect_type}(#{use_broker ? 'via broker' : 'directly'}):#{miqVimHost[:address]}"
      $log.info "#{log_header}: Connecting to [#{ems_display_text}] for VM:[#{@vm_cfg_file}]"
      miqVimHost[:password_decrypt] = MiqPassword.decrypt(miqVimHost[:password])

      begin
        #
        # The functionality that was formerly required through 'rhevm_inventory'
        # has been moved to the 'overt' gem. If that functionality is ever moved
        # out of the 'overt' gem, then this require will need to be changed accordingly.
        #
        $log.debug "#{log_header}: before require 'overt'"
        require 'ovirt'
        ems_opt = {
          :server     => miqVimHost[:address],
          :username   => miqVimHost[:username],
          :password   => miqVimHost[:password_decrypt],
          :verify_ssl => false
        }
        ems_opt[:port] = miqVimHost[:port] unless miqVimHost[:port].blank?

        rhevm = Ovirt::Inventory.new(ems_opt)
        rhevm.api
        ost.miqRhevm = rhevm
        $log.info "Connection to [#{ems_display_text}] completed for VM:[#{@vm_cfg_file}] in [#{Time.now - st}] seconds"
      rescue Timeout::Error => err
        msg = "#{log_header}: Connection to [#{ems_display_text}] timed out for VM:[#{@vm_cfg_file}] with error [#{err}] after [#{Time.now - st}] seconds"
        $log.error msg
        raise err, msg, err.backtrace
      rescue Exception => err
        msg = "#{log_header}: Connection to [#{ems_display_text}] failed for VM:[#{@vm_cfg_file}] with error [#{err}] after [#{Time.now - st}] seconds"
        $log.error msg
        raise err, msg, err.backtrace
      end
    end
  end
end
