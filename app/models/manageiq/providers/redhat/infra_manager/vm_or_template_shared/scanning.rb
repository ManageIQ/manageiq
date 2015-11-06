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

    st = Time.now
    ems_display_text = "ems(directly):#{ext_management_system.address}"
    $log.info "#{log_header}: Connecting to [#{ems_display_text}] for VM:[#{@vm_cfg_file}]"

    begin
      ost.miqRhevm = ext_management_system.rhevm_inventory
      $log.info "Connection to [#{ems_display_text}] completed for VM:[#{@vm_cfg_file}] in [#{Time.now - st}] seconds"
    rescue Timeout::Error => err
      msg = "#{log_header}: Connection to [#{ems_display_text}] timed out for VM:[#{@vm_cfg_file}] with error [#{err}] after [#{Time.now - st}] seconds"
      $log.error msg
      raise
    rescue Exception => err
      msg = "#{log_header}: Connection to [#{ems_display_text}] failed for VM:[#{@vm_cfg_file}] with error [#{err}] after [#{Time.now - st}] seconds"
      $log.error msg
      raise
    end
  end
end
