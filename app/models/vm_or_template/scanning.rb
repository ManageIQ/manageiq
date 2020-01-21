module VmOrTemplate::Scanning
  extend ActiveSupport::Concern

  # Call the VmScan Job and raise a "request" event
  def scan(userid = "system", options = {})
    # Check if there are any current scan jobs already waiting to run
    j = VmScan.where(:state => 'waiting_to_start')
        .where(:sync_key => guid)
        .pluck(:id)
    unless j.blank?
      _log.info("VM scan job will not be added due to existing scan job waiting to be processed.  VM ID:[#{id}] Name:[#{name}] Guid:[#{guid}]  Existing Job IDs [#{j.join(", ")}]")
      return nil
    end

    check_policy_prevent(:request_vm_scan, :raw_scan, userid, options)
  end

  def scan_job_class
    VmScan
  end

  def raw_scan(userid = "system", options = {})
    options = {
      :target_id    => id,
      :target_class => self.class.base_class.name,
      :name         => "Scan from Vm #{name}",
      :userid       => userid,
      :sync_key     => guid,
    }.merge(options)
    options[:zone] = ext_management_system.my_zone unless ext_management_system.nil?

    _log.info("NAME [#{options[:name]}] SCAN [#{options[:categories].inspect}] [#{options[:categories].class}]")

    self.last_scan_attempt_on = Time.now.utc
    save
    job = scan_job_class.create_job(options)
    return job
  rescue => err
    _log.log_backtrace(err)
    raise
  end

  #
  # Default Adjustment Multiplier is 1 (i.e. no change to timeout)
  #   since this is a multiplier, timeout * 1 = timeout
  #
  # Subclasses MAY choose to override this
  #
  module ClassMethods
    def scan_timeout_adjustment_multiplier
      1
    end
  end

  #
  # Instance method delegates to class method for convenience
  #
  def scan_timeout_adjustment_multiplier
    self.class.scan_timeout_adjustment_multiplier
  end

  #
  # Subclasses need to override this method if a storage association
  # is not required for SSA.
  #
  def requires_storage_for_scan?
    true
  end

  #
  # Provider subclasses should override this method, if they support SmartState Analysis
  #
  def require_snapshot_for_scan?
    raise NotImplementedError, "must be implemented in provider subclass"
  end
end
