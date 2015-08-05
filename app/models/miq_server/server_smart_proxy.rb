$LOAD_PATH << File.join(GEMS_PENDING_ROOT, "Verbs")
$LOAD_PATH << File.join(GEMS_PENDING_ROOT, "VixDiskLib")
require 'yaml'

module MiqServer::ServerSmartProxy
  extend ActiveSupport::Concern

  included do
    serialize :capabilities
  end

  module ClassMethods
    # Called from VM scan job as well as scan_sync_vm

    def use_broker_for_embedded_proxy?(type=nil)
      cores_settings = MiqServer.my_server.get_config("vmdb").config[:coresident_miqproxy].dup
      result = ManageIQ::Providers::Vmware::InfraManager.use_vim_broker? && cores_settings[:use_vim_broker]

      # Check for a specific type (host/ems) if passed
      unless type.blank?
        # Default use_vim_broker to true for ems type
        cores_settings[:use_vim_broker_ems] = true if cores_settings[:use_vim_broker_ems].blank? && cores_settings[:use_vim_broker_ems] != false
        cores_settings["use_vim_broker_#{type}".to_sym] ||= false
        result = result && cores_settings["use_vim_broker_#{type}".to_sym]
      end
      result
    end
  end

  def is_a_proxy?
    self.has_role?(:SmartProxy)
  end

  def is_proxy_active?
    self.started? && self.has_active_role?(:SmartProxy)
  end

  def is_vix_disk?
    self.has_active_role?(:SmartProxy) && self.capabilities && self.capabilities[:vixDisk]
  end

  def vm_scan_host_affinity?
    with_relationship_type("vm_scan_affinity") { has_children? }
  end

  def vm_scan_host_affinity=(hosts)
    hosts = [hosts].flatten
    with_relationship_type("vm_scan_affinity") do
      replace_children(hosts)
    end
  end

  def vm_scan_host_affinity
    with_relationship_type("vm_scan_affinity") { children }
  end

  def vm_scan_storage_affinity?
    with_relationship_type("vm_scan_storage_affinity") { has_children? }
  end

  def vm_scan_storage_affinity=(storages)
    storages = [storages].flatten
    with_relationship_type("vm_scan_storage_affinity") do
      replace_children(storages)
    end
  end

  def vm_scan_storage_affinity
    with_relationship_type("vm_scan_storage_affinity") { children }
  end

  def call_ws(ost)
    case ost.method_name
    when "ScanMetadata", "SyncMetadata"
      worker_setting = MiqSmartProxyWorker.worker_settings
      #
      # TODO: until we get location/offset read capability for OpenStack
      # image data, OpenStack fleecing is prone to timeout (based on image size).
      # We try to adjust the timeout here - maybe this should be calculated based
      # on the size of the image, but that information isn't directly available.
      #
      timeout_adj = 1
      if ost.method_name == "ScanMetadata"
        v = VmOrTemplate.find(ost.vm_id)
        timeout_adj = 4 if v.kind_of?(VmOpenstack) || v.kind_of?(TemplateOpenstack)
      end
      $log.debug "#{log_prefix}: queuing call to #{self.class.name}##{ost.method_name.underscore}"
      # Queue call to scan_metadata or sync_metadata.
      MiqQueue.put(:class_name => self.class.name, :instance_id => id, :method_name => ost.method_name.underscore, :args => ost, :server_guid => guid, :role => "smartproxy", :queue_name => "smartproxy", :msg_timeout => worker_setting[:queue_timeout] * timeout_adj)
    else
      _log.error "Unsupported method [#{ost.method_name}]"
    end
  end

  def scan_metadata(ost)
    v   = VmOrTemplate.find(ost.vm_id)
    job = Job.find_by_guid(ost.taskid)
    _log.debug "#{v.name} (#{v.class.name})"
    begin
      ost.args[1]  = YAML.load(ost.args[1]) # TODO: YAML.dump'd in call_scan - need it be?
      ost.scanData = ost.args[1].is_a?(Hash) ? ost.args[1] : {}
      ost.config = OpenStruct.new(
        :vmdb => true,
        :forceFleeceDefault => true,
        :capabilities => self.capabilities
      )

      v.perform_metadata_scan(ost)
    rescue Exception => err
      _log.error err.to_s
      _log.debug err.backtrace.join("\n")
      job.signal(:abort_retry, err.to_s, "error", true)
      return
    end
  end

  def sync_metadata(ost)
    v   = VmOrTemplate.find(ost.vm_id)
    job = Job.find_by_guid(ost.taskid)
    $log.debug "#{log_prefix}: #{v.name} (#{v.class.name})"
    begin
      v.perform_metadata_sync(ost)
    rescue Exception => err
      _log.error err.to_s
      _log.debug err.backtrace.join("\n")
      job.signal(:abort_retry, err.to_s, "error", true)
      return
    end
  end

  def print_backtrace(errStr)
    errArray = errStr.strip.split("\n")

    # If the log level is greater than "debug" just dump the first 2 error lines
    errArray = errArray[0,2] if $log.level > 1

    # Print the stack trace to debug logging level
    errArray.each {|e| $log.error "Error Trace: [#{e}]"}
  end

  def miq_proxy
    self
  end

  def forceVmScan
    true
  end

  # TODO: This should be moved - where?
  def is_vix_disk_supported?
    caps = {:vixDisk => false}
    begin
      # This is only available on Linux
      if Platform::IMPL == :linux
        # We now rely on the server role to determine if we want to enable server scanning.
        # Check if we want to expose this functionality
        #        unless get_config("vmdb").config[:server][:vix_disk_enabled] == false
        require 'VixDiskLib'
        caps[:vixDisk] = true
        #        end
      end
    rescue Exception => err
      # It is ok if we hit an error, it just means the library is not available to load.
    end

    caps[:vixDisk]
  end

  def concurrent_job_max
    self.update_capabilities
    self.capabilities[:concurrent_miqproxies].to_i
  end

  def max_concurrent_miqproxies
    return 0 unless self.is_a_proxy?
    MiqSmartProxyWorker.worker_settings[:count]
  end

  def update_capabilities
    self.capabilities = {} if self.capabilities.nil?
    # We can only update these values if we are working on the local server
    # since they are determined by local resources.
    if MiqServer.my_server == self
      self.capabilities[:vixDisk] = self.is_vix_disk_supported?
      self.capabilities[:concurrent_miqproxies] = self.max_concurrent_miqproxies
    end
  end

end
