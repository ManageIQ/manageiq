module ManageIQ::Providers::Redhat::InfraManager::VmOrTemplateShared::Scanning
  extend ActiveSupport::Concern

  included do
    supports :smartstate_analysis do
      feature_supported, reason = check_feature_support('smartstate_analysis')
      unless feature_supported
        unsupported_reason_add(:smartstate_analysis, reason)
      end
    end
  end

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

  RHEVM_NO_PROXIES_ERROR_MSG = N_('VMs must be scanned from an EVM server whose host is attached to the same
  storage as the VM unless overridden via SmartProxy affinity.
  Please verify that:
  1) Direct LUNs are attached to ManageIQ appliance
  2) Management Relationship is set for the ManageIQ appliance')

  def proxies4job(job = nil)
    _log.debug "Enter (RHEVM)"
    msg = N_('Perform SmartState Analysis on this VM')

    # If we do not get passed an model object assume it is a job guid
    if job && !job.kind_of?(ActiveRecord::Base)
      jobid = job
      job = Job.find_by(:guid => jobid)
    end

    all_proxy_list = storage2proxies
    proxies = storage2active_proxies(all_proxy_list)
    _log.debug "# proxies = #{proxies.length}"

    if proxies.empty?
      msg = RHEVM_NO_PROXIES_ERROR_MSG
      log_proxies(proxies, all_proxy_list, msg, job) if job
    end

    {:proxies => proxies.flatten, :message => _(msg)}
  end

  def miq_server_proxies
    _log.debug "Enter (RHEVM)"

    _log.debug "RedHat: storage_id.blank? = #{storage_id.blank?}"
    return [] if storage_id.blank?

    miq_servers = select_miq_servers(servers_by_storage_affinity)

    _log.debug "miq_servers2.length = #{miq_servers.length}"

    miq_servers
  end

  private

  def servers_by_storage_affinity
    storage_server_ids = groups_of_vms_in_affinity_to_storage

    all_storage_server_ids = flat_storage_server_ids(storage_server_ids)

    srs = self.class.miq_servers_for_scan
    _log.debug "srs.length = #{srs.length}"

    miq_servers = srs.select do |svr|
      svr.vm_scan_storage_affinity? ? all_storage_server_ids.detect { |id| id == svr.id } : storage_server_ids.empty?
    end
    _log.debug "miq_servers1.length = #{miq_servers.length}"

    miq_servers
  end

  def groups_of_vms_in_affinity_to_storage
    storage_server_ids = storages.collect { |s| s.vm_scan_affinity.collect(&:id) }.reject(&:blank?)
    _log.debug "storage_server_ids.length = #{storage_server_ids.length}"
    storage_server_ids
  end

  def flat_storage_server_ids(group_storage_server_ids)
    all_storage_server_ids = group_storage_server_ids.inject(:&) || []
    _log.debug "all_storage_server_ids.length = #{all_storage_server_ids.length}"
    all_storage_server_ids
  end

  def select_miq_servers(miq_servers)
    miq_servers.select do |svr|
      # RedHat VMs must be scanned from an EVM server who's host is attached to the same
      # storage as the VM unless overridden via SmartProxy affinity
      started_in_same_zone?(svr) && (svr.vm_scan_storage_affinity? || same_storage_ids?(svr))
    end
  end

  def started_in_same_zone?(svr)
    svr.status == "started" && svr.has_zone?(my_zone)
  end

  def same_storage_ids?(svr)
    svr_vm = svr.vm
    return false unless svr_vm && svr_vm.host
    missing_storage_ids = storages.collect(&:id) - svr_vm.host.storages.collect(&:id)
    missing_storage_ids.empty?
  end

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
