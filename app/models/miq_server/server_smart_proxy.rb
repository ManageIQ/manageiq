require 'yaml'

module MiqServer::ServerSmartProxy
  extend ActiveSupport::Concern

  SMART_ROLES = %w(smartproxy smartstate).freeze

  def is_a_proxy?
    self.has_role?(:SmartProxy)
  end

  def is_proxy_active?
    self.started? && self.has_active_role?(:SmartProxy)
  end

  def is_vix_disk?
    has_vix_disk_lib? && self.has_active_role?(:SmartProxy)
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

      timeout_adjustment_multiplier = 1
      if ost.method_name == "scan_metadata"
        klass = ost.target_type.constantize
        target = klass.find(ost.target_id)
        if target.respond_to?(:scan_timeout_adjustment_multiplier)
          timeout_adjustment_multiplier = target.scan_timeout_adjustment_multiplier
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
        :msg_timeout => worker_setting[:queue_timeout] * timeout_adjustment_multiplier
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
        :capabilities       => {:vixDisk => has_vix_disk_lib?}
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

  def concurrent_job_max
    return 0 unless self.is_a_proxy?

    MiqSmartProxyWorker.fetch_worker_settings_from_server(self)[:count].to_i
  end
end
