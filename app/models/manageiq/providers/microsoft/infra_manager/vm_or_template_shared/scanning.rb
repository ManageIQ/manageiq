module ManageIQ::Providers::Microsoft::InfraManager::VmOrTemplateShared::Scanning
  def perform_metadata_scan(ost)
    require 'MiqVm/miq_scvmm_vm'

    log_pref = "MIQ(#{self.class.name}##{__method__})"
    vm_name  = name
    $log.debug "#{log_pref} VM = #{vm_name}"

    begin
      $log.debug "perform_metadata_scan: vm_name = #{vm_name}"
      connect_to_ems(vm_name, ost)
      miq_vm = MiqScvmmVm.new(vm_name, ost)
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
  def connect_to_ems(vm_name, ost)
    log_header = "MIQ(#{self.class.name}.#{__method__})"

    # Check if we've been told explicitly not to connect to the ems
    if ost.scanData.fetch_path("ems", 'connect') == false
      $log.debug "#{log_header}: returning, ems/connect == false"
      return
    end

    # Make sure we were given a ems/host to connect to
    ems_connect_type = ost.scanData.fetch_path('ems', 'connect_to') || 'host'
    miq_vm_host = ost.scanData.fetch_path("ems", ems_connect_type)
    if miq_vm_host
      st = Time.now.getlocal
      use_broker = false
      miq_vm_host[:address] = miq_vm_host[:ipaddress] if miq_vm_host[:address].nil?
      ems_text = "#{ems_connect_type}(#{use_broker ? 'via broker' : 'directly'}):#{miq_vm_host[:address]}"
      log.text = "#{log_header}: Connection to [#{ems_text}]"
      $log.info "#{log_header}: Connecting to [#{ems_text}] for VM:[#{vm_name}]"
      miq_vm_host[:password_decrypt] = MiqPassword.decrypt(miq_vm_host[:password])

      begin
        hyperv_config = {:host     => miq_vm_host[:address],
                         :port     => miq_vm_host[:port],
                         :user     => miq_vm_host[:username],
                         :password => miq_vm_host[:password_decrypt],
        }

        ost.miq_scvmm  = ost.miq_hyperv = hyperv_config
        ost.miq_vm     = ost.fileName = vm_name
        $log.info "#{log_text} completed for VM:[#{vm_name}] in [#{Time.now.getlocal - st}] seconds"
      rescue Timeout::Error => err
        msg = "#{log_text} timed out for VM:[#{vm_name}] with error [#{err}] after [#{Time.now.getlocal - st}] seconds"
        $log.error msg
        raise err, msg, err.backtrace
      rescue Exception => err
        msg = "#{log_text} failed for VM:[#{vm_name}] with error [#{err}] after [#{Time.now.getlocal - st}] seconds"
        $log.error msg
        raise err, msg, err.backtrace
      end
    end
  end
end
