# TODO: Nothing appears to be using xml_utils in this file???
# Perhaps, it's being required here because lower level code requires xml_utils to be loaded
# but wrongly doesn't require it itself.
$LOAD_PATH << File.join(GEMS_PENDING_ROOT, "util/xml")
require 'xml_utils'
require 'blackbox/VmBlackBox'

module VmOrTemplate::Scanning
  extend ActiveSupport::Concern

  # Call the VmScan Job and raise a "request" event
  def scan(userid = "system", options = {})
    # Check if there are any current scan jobs already waiting to run
    j = VmScan.where(:state => 'waiting_to_start')
        .where(:sync_key => guid)
        .pluck(:id)
    unless j.blank?
      _log.info "VM scan job will not be added due to existing scan job waiting to be processed.  VM ID:[#{id}] Name:[#{name}] Guid:[#{guid}]  Existing Job IDs [#{j.join(", ")}]"
      return nil
    end

    options = {
      :target_id    => id,
      :target_class => self.class.base_class.name,
      :name         => "Scan from Vm #{name}",
      :userid       => userid,
      :sync_key     => guid,
    }.merge(options)
    options[:zone] = ext_management_system.my_zone unless ext_management_system.nil?
    # options = {:agent_id => myhost.id, :agent_class => myhost.class.to_s}.merge!(options) unless myhost.nil?
    # self.vm_state.power_state == "on" ? options[:force_snapshot] = true : options[:force_snapshot] = false

    _log.info "NAME [#{options[:name]}] SCAN [#{options[:categories].inspect}] [#{options[:categories].class}]"

    begin
      inputs = {:vm => self, :host => host}
      MiqEvent.raise_evm_job_event(self, {:type => "scan", :prefix => "request"}, inputs)
    rescue => err
      _log.warn("NAME [#{options[:name]}] #{err.message}")
      return
    end

    begin
      self.last_scan_attempt_on = Time.now.utc
      save
      job = Job.create_job("VmScan", options)
      return job
    rescue => err
      _log.log_backtrace(err)
      raise
    end
  end

  #
  # Smartstate Analysis is unsupported by default.
  # Subclasses need to override this method if they support SSA.
  #
  def validate_smartstate_analysis
    validate_unsupported("Smartstate Analysis")
  end

  #
  # Subclasses need to override this method if a storage association
  # is not required for SSA.
  #
  def requires_storage_for_scan?
    true
  end

  # TODO: Vmware specfic
  def require_snapshot_for_scan?
    return false unless self.runnable?
    return false if ['redhat'].include?(vendor.downcase)
    return false if host && host.platform == "windows"
    true
  end
end
