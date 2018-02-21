require 'yaml'

module MiqServer::ServerSmartProxy
  extend ActiveSupport::Concern

  SMART_ROLES = %w(smartproxy smartstate).freeze

  included do
    serialize :capabilities
  end

  module ClassMethods
    # Called from VM scan job as well as scan_sync_vm

    def use_broker_for_embedded_proxy?(type = nil)
      result = ManageIQ::Providers::Vmware::InfraManager.use_vim_broker? &&
               ::Settings.coresident_miqproxy[:use_vim_broker]
      return result if type.blank? || !result

      # Check for a specific type (host/ems) if passed
      # Default use_vim_broker is true for ems type
      ::Settings.coresident_miqproxy["use_vim_broker_#{type}"] == true
    end
  end

  def is_a_proxy?
    self.has_role?(:SmartProxy)
  end

  def is_proxy_active?
    self.started? && self.has_active_role?(:SmartProxy)
  end

  def is_vix_disk?
    self.has_active_role?(:SmartProxy) && capabilities && capabilities[:vixDisk]
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

  def queue_call(ost)
    case ost.method_name
    when "scan_metadata", "sync_metadata"
      worker_setting = MiqSmartProxyWorker.worker_settings
      #
      # TODO: until we get location/offset read capability for OpenStack
      # image data, OpenStack fleecing is prone to timeout (based on image size).
      # We try to adjust the timeout here - maybe this should be calculated based
      # on the size of the image, but that information isn't directly available.
      #
      timeout_adj = 1
      if ost.method_name == "scan_metadata"
        klass = ost.target_type.constantize
        target = klass.find(ost.target_id)
        if target.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Vm) ||
           target.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Template)
          timeout_adj = 4
        elsif target.kind_of?(ManageIQ::Providers::Azure::CloudManager::Vm) ||
              target.kind_of?(ManageIQ::Providers::Azure::CloudManager::Template)
          timeout_adj = 4
        elsif target.kind_of?(ManageIQ::Providers::Microsoft::InfraManager::Vm) ||
              target.kind_of?(ManageIQ::Providers::Microsoft::InfraManager::Template)
          timeout_adj = 8
        end
      end
      _log.debug("queuing call to #{self.class.name}##{ost.method_name}")
      # Queue call to scan_metadata or sync_metadata.
      MiqQueue.submit_job(
        :service     => "smartproxy",
        :class_name  => self.class.name,
        :instance_id => id,
        :method_name => ost.method_name,
        :args        => ost,
        :server_guid => guid, # this should be derived in service. fix this
        :msg_timeout => worker_setting[:queue_timeout] * timeout_adj
      )
    else
      _log.error("Unsupported method [#{ost.method_name}]")
    end
  end

  # Called through Queue by Job
  def scan_metadata(ost)
    klass  = ost.target_type.constantize
    target = klass.find(ost.target_id)
    job    = Job.find_by(:guid => ost.taskid)
    _log.debug("#{target.name} (#{target.class.name})")
    begin
      ost.args[1]  = YAML.load(ost.args[1]) # TODO: YAML.dump'd in call_scan - need it be?
      ost.scanData = ost.args[1].kind_of?(Hash) ? ost.args[1] : {}
      ost.jobid    = job.id
      ost.config = OpenStruct.new(
        :vmdb               => true,
        :forceFleeceDefault => true,
        :capabilities       => capabilities
      )

      target.perform_metadata_scan(ost)
    rescue Exception => err
      _log.error(err.to_s)
      _log.log_backtrace(err, :debug)
      job.signal(:abort_retry, err.to_s, "error", true)
      return
    end
  end

  # Called through Queue by Job
  def sync_metadata(ost)
    klass  = ost.target_type.constantize
    target = klass.find(ost.target_id)
    job    = Job.find_by(:guid => ost.taskid)
    _log.debug("#{target.name} (#{target.class.name})")
    begin
      target.perform_metadata_sync(ost)
    rescue Exception => err
      _log.error(err.to_s)
      _log.log_backtrace(err, :debug)
      job.signal(:abort_retry, err.to_s, "error", true)
      return
    end
  end

  def print_backtrace(errStr)
    errArray = errStr.strip.split("\n")

    # If the log level is greater than "debug" just dump the first 2 error lines
    errArray = errArray[0, 2] if $log.level > 1

    # Print the stack trace to debug logging level
    errArray.each { |e| $log.error("Error Trace: [#{e}]") }
  end

  def forceVmScan
    true
  end

  # TODO: This should be moved - where?
  def is_vix_disk_supported?
    caps = {:vixDisk => false}
    begin
      # This is only available on Linux
      if Sys::Platform::IMPL == :linux
        require 'VMwareWebService/VixDiskLib/VixDiskLib'
        caps[:vixDisk] = true
      end
    rescue Exception
      # It is ok if we hit an error, it just means the library is not available to load.
    end

    caps[:vixDisk]
  end

  def concurrent_job_max
    update_capabilities
    capabilities[:concurrent_miqproxies].to_i
  end

  def max_concurrent_miqproxies
    return 0 unless self.is_a_proxy?
    MiqSmartProxyWorker.worker_settings[:count]
  end

  def update_capabilities
    self.capabilities = {} if capabilities.nil?
    # We can only update these values if we are working on the local server
    # since they are determined by local resources.
    if MiqServer.my_server == self
      capabilities[:vixDisk] = self.is_vix_disk_supported?
      capabilities[:concurrent_miqproxies] = max_concurrent_miqproxies
    end
  end
end
