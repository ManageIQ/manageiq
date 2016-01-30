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

  def proxies4job(job = nil)
    _log.debug "Enter (RHEVM)"
    msg = 'Perform SmartState Analysis on this VM'

    # If we do not get passed an model object assume it is a job guid
    if job && !job.kind_of?(ActiveRecord::Base)
      jobid = job
      job = Job.find_by_guid(jobid)
    end

    all_proxy_list = storage2proxies
    proxies = storage2active_proxies(all_proxy_list)
    _log.debug "# proxies = #{proxies.length}"

    if proxies.empty?
      msg = 'No active SmartProxies found to analyze this VM'
      log_proxies(proxies, all_proxy_list, msg, job) if job
    end

    {:proxies => proxies.flatten, :message => msg}
  end

  def validate_smartstate_analysis
    validate_supported_check("Smartstate Analysis")
  end

  def miq_server_proxies
    _log.debug "Enter (RHEVM)"

    _log.debug "RedHat: storage_id.blank? = #{storage_id.blank?}"
    return [] if storage_id.blank?

    storage_server_ids = storages.collect { |s| s.vm_scan_affinity.collect(&:id) }.reject(&:blank?)
    _log.debug "storage_server_ids.length = #{storage_server_ids.length}"

    all_storage_server_ids = storage_server_ids.inject(:&) || []
    _log.debug "all_storage_server_ids.length = #{all_storage_server_ids.length}"

    srs = self.class.miq_servers_for_scan
    _log.debug "srs.length = #{srs.length}"

    miq_servers = srs.select do |svr|
      svr.vm_scan_storage_affinity? ? all_storage_server_ids.detect { |id| id == svr.id } : storage_server_ids.empty?
    end
    _log.debug "miq_servers1.length = #{miq_servers.length}"

    miq_servers.select! do |svr|
      result = svr.status == "started" && svr.has_zone?(my_zone)
      # RedHat VMs must be scanned from an EVM server who's host is attached to the same
      # storage as the VM unless overridden via SmartProxy affinity
      unless svr.vm_scan_storage_affinity?
        svr_vm = svr.vm
        if svr_vm && svr_vm.host
          missing_storage_ids = storages.collect(&:id) - svr_vm.host.storages.collect(&:id)
          result &&= missing_storage_ids.empty?
        else
          result = false
        end
      end
      result
    end
    _log.debug "miq_servers2.length = #{miq_servers.length}"
    miq_servers
  end

  private

  def storage2active_proxies(all_proxy_list = nil)
    _log.debug "Enter (RHEVM)"

    all_proxy_list ||= storage2proxies
    _log.debug "all_proxy_list.length = #{all_proxy_list.length}"
    proxies = all_proxy_list.select(&:is_proxy_active?)
    _log.debug "proxies.length = #{proxies.length}"

    proxies
  end

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
