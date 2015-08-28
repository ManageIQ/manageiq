# TODO: Nothing appears to be using xml_utils in this file???
# Perhaps, it's being required here because lower level code requires xml_utils to be loaded
# but wrongly doesn't require it itself.
$LOAD_PATH << File.join(GEMS_PENDING_ROOT, "util/xml")
require 'xml_utils'

require 'blackbox/VmBlackBox'
require 'Verbs/miqservices_client'

module VmOrTemplate::Scanning
  extend ActiveSupport::Concern

  # Call the VmScan Job and raise a "request" event
  def scan(userid = "system", options={})
    # Check if there are any current scan jobs already waiting to run
    j = VmScan.where(:state => 'waiting_to_start')
          .where(:sync_key => guid)
          .pluck(:id)
    unless j.blank?
      _log.info "VM scan job will not be added due to existing scan job waiting to be processed.  VM ID:[#{self.id}] Name:[#{self.name}] Guid:[#{self.guid}]  Existing Job IDs [#{j.join(", ")}]"
      return nil
    end

    options = {
      :target_id => self.id,
      :target_class => self.class.base_class.name,
      :name => "Scan from Vm #{self.name}",
      :userid => userid,
      :sync_key => self.guid
    }.merge(options)
    options[:zone] = self.ext_management_system.my_zone unless self.ext_management_system.nil?
    # options = {:agent_id => myhost.id, :agent_class => myhost.class.to_s}.merge!(options) unless myhost.nil?
    # self.vm_state.power_state == "on" ? options[:force_snapshot] = true : options[:force_snapshot] = false

    _log.info "NAME [#{options[:name]}] SCAN [#{options[:categories].inspect}] [#{options[:categories].class}]"

    begin
      inputs = {:vm => self, :host => self.host}
      MiqEvent.raise_evm_job_event(self, {:type => "scan", :prefix => "request"}, inputs)
    rescue => err
      _log.warn("NAME [#{options[:name]}] #{err.message}")
      return
    end

    begin
      self.last_scan_attempt_on = Time.now.utc
      self.save
      job = Job.create_job("VmScan", options)
      return job
    rescue => err
      _log.log_backtrace(err)
      raise
    end
  end

  # TODO: Vmware specfic
  def require_snapshot_for_scan?
    return false unless self.runnable?
    return false if ['RedHat'].include?(self.vendor)
    return false if self.host && self.host.platform == "windows"
    return true
  end
end
