class MiqRequest < ActiveRecord::Base
  ACTIVE_STATES = %w{ active queued }

  belongs_to :source,            :polymorphic => true
  belongs_to :destination,       :polymorphic => true
  belongs_to :requester,         :class_name => "User"
  has_many   :miq_approvals,     :dependent => :destroy
  has_many   :miq_request_tasks, :dependent => :destroy

  alias_attribute :state, :request_state

  serialize   :options, Hash

  default_value_for :options,       {}
  default_value_for :status,        'Ok'
  default_value_for :request_state, 'pending'

  validates_inclusion_of :approval_state, :in => %w{ pending_approval approved denied }, :message => "should be 'pending_approval', 'approved' or 'denied'"
  validates_inclusion_of :status,         :in => %w{ Ok Warn Error Timeout Denied}

#  validate :must_have_valid_requester

  include ReportableMixin

  virtual_column  :reason,              :type => :string, :uses => :miq_approvals
  virtual_column  :v_approved_by,       :type => :string, :uses => :miq_approvals
  virtual_column  :v_approved_by_email, :type => :string, :uses => {:miq_approvals => :stamper}
  virtual_column  :stamped_on,          :type => :datetime, :uses => :miq_approvals
  virtual_column  :request_type_display,:type => :string
  virtual_column  :resource_type,       :type => :string
  virtual_column  :state,               :type => :string

  before_validation :initialize_attributes, :on => :create

  include MiqRequestMixin

  MODEL_REQUEST_TYPES = {
    :Vm                => {
      :MiqProvisionRequest             => {
        :template          => "VM Provision",
        :clone_to_vm       => "VM Clone",
        :clone_to_template => "VM Publish",
      },
      :VmReconfigureRequest            => {
        :vm_reconfigure => "VM Reconfigure"
      },
      :VmMigrateRequest                => {
        :vm_migrate => "VM Migrate"
      },
      :ServiceTemplateProvisionRequest => {
        :clone_to_service => "Service Provision"
      },
      :ServiceReconfigureRequest       => {
        :service_reconfigure => "Service Reconfigure"
      }
    },
    :Host              => {
      :MiqHostProvisionRequest => {
        :host_pxe_install => "Host Provision"
      },
    },
    :AutomationRequest => {
      :AutomationRequest => {
        :automation => "Automation"
      }
    }
  }

  REQUEST_TYPES = {
    :MiqProvisionRequest             => {
      :template          => "VM Provision",
      :clone_to_vm       => "VM Clone",
      :clone_to_template => "VM Publish",
    },
    :MiqProvisionRequestTemplate     => {
      :template => "VM Provision Template"
    },
    :MiqHostProvisionRequest         => {
      :host_pxe_install => "Host Provision"
    },
    :VmReconfigureRequest            => {
      :vm_reconfigure => "VM Reconfigure"
    },
    :VmMigrateRequest                => {
      :vm_migrate => "VM Migrate"
    },
    :AutomationRequest               => {
      :automation => "AutomationRequest"
    },
    :ServiceTemplateProvisionRequest => {
      :clone_to_service => "Service Provision"
    },
    :ServiceReconfigureRequest       => {
      :service_reconfigure => "Service Reconfigure"
    }
  }

  # Supports old-style requests where specific request was a seperate table connected as a resource
  def resource
    self
  end

  def miq_request
    self
  end

  def resource_type
    self.class.name
  end

  def initialize_attributes
    self.requester_name ||= self.requester.name                      if self.requester.kind_of?(User)
    self.requester      ||= User.find_by_name(self.requester_name)   if self.requester_name.kind_of?(String)
    self.approval_state ||= "pending_approval"
    self.miq_approvals   << self.build_default_approval
  end

  # TODO: Move call_automate_event_queue from MiqProvisionWorkflow to be done here automagically
  # Seems like we need to call automate after the MiqProvisionRequest in SQL and wired back to this object
  #
  # after_create do
  #   self.call_automate_event_queue("request_created")
  # end
  #
  # after_update do
  #   self.call_automate_event_queue("request_updated")
  # end

  def must_have_valid_requester
    errors.add(:requester, "must have valid requester") unless self.requester.kind_of?(User)
  end

  def must_have_user
    errors.add(:userid, "must have valid user") unless self.userid && User.exists?(:userid => self.userid)
  end

  def call_automate_event_queue(event_name)
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => "call_automate_event",
      :args        => [event_name],
      :zone        => MiqServer.my_zone,
      :msg_timeout => 3600
    )
  end

  def call_automate_event(event_name)
    log_header = "MIQ(#{self.class.name}.call_automate_event)"
    begin
      $log.info("#{log_header} Raising event [#{event_name}] to Automate")
      ws = MiqAeEvent.raise_evm_event(event_name, self)
      $log.info("#{log_header} Raised  event [#{event_name}] to Automate")
      return ws
    rescue MiqAeException::Error => err
      message = "Error returned from #{event_name} event processing in Automate: #{err.message}"
      raise
    end
  end

  def automate_event_failed?(event_name)
    log_header = "MIQ(#{self.class.name}.automate_event_failed?)"

    ws = call_automate_event(event_name)

    if ws.nil?
      $log.warn("#{log_header} Aborting because Automate failed for event <#{event_name}>")
      return true
    end

    if ws.root['ae_result'] == 'error'
      $log.warn("#{log_header} Aborting because Automate returned ae_result=<#{ws.root['ae_result']}> for event <#{event_name}>")
      return true
    end

    return false
  end

  def pending
    call_automate_event_queue("request_pending")
  end

  def approval_approved
    log_prefix = "MIQ(#{self.class.name}.approve)"
    unless self.approved?
      $log.info("#{log_prefix} Request: [#{self.description}] has outstanding approvals")
      return false
    end

    self.update_attributes(:approval_state => "approved")
    call_automate_event_queue("request_approved")

    # execute parent now that request is approved
    $log.info("#{log_prefix} Request: [#{self.description}] has all approvals approved, proceeding with execution")
    begin
      self.execute
    rescue => err
      $log.error("#{log_prefix} #{err.message}, attempting to execute request: [#{self.description}]")
      $log.error("#{log_prefix} #{err.backtrace.join("\n")}")
    end

    return true
  end

  def approval_denied
    self.update_attributes(:approval_state => "denied", :request_state => "finished", :status => "Denied")
    call_automate_event_queue("request_denied")
  end

  def approved?
    self.miq_approvals.each { |a| return false unless a.state == "approved" }
    return true
  end

  def v_approved_by
    self.miq_approvals.collect {|a| a.stamper_name}.compact.join(", ")
  end

  def v_approved_by_email
    emails = self.miq_approvals.inject([]) {|arr,a| arr << a.stamper.email unless a.stamper.nil? || a.stamper.email.nil?; arr}
    emails.join(", ")
  end

  def get_options
    self.options || {}
  end

  def request_type_display
    return "Unknown" if self.request_type.nil?
    REQUEST_TYPES[self.type.to_sym][self.request_type.to_sym].to_s
  end

  def request_status
    return self.status if self.approval_state == 'approved' && !self.status.nil?
    case self.approval_state
    when 'pending_approval' then 'Unknown'
    when 'denied'           then 'Error'
    else 'Unknown'
    end
  end

  def build_default_approval
    MiqApproval.new(:description => "Default Approval")
  end

  def self.requests_for_userid(userid)
    requester = User.find_by_userid(userid)
    return [] unless requester
    return self.find_all_by_requester_id(requester.id)
  end

  def self.all_requesters(conditions=nil)
    self.find(:all,
      :conditions => conditions,
      :select     => "requester_id, requester_name",
      :group      => "requester_id, requester_name",
      :include    => "requester"
    ).inject({}) do |h,r|
      h[r.requester_id] = (r.requester.nil? ? "#{r.requester_name} (no longer exists)" : r.requester_name)
      h
    end
  end

  # TODO: Helper methods to support UI in legacy mode - single approval by role
  #       These should be removed once multi-approver is fully supported.
  def first_approval
    self.miq_approvals.first || self.build_default_approval
  end

  def approve(userid, reason)
    self.first_approval.approve(userid, reason) unless self.approved?
  end

  def deny(userid, reason)
    self.first_approval.deny(userid, reason)
  end

  def stamped_by
    self.first_approval.stamper ? self.first_approval.stamper.userid : nil
  end

  def reason
    self.first_approval.reason
  end

  def stamped_on
    self.first_approval.stamped_on
  end

  def approver
    self.first_approval.approver.try(:name)
  end

  alias_method :approver_role, :approver  # TODO: Is this needed anymore?

  def requester_userid
    self.requester.userid
  end
  #######

  def workflow_class
    klass = self.class.workflow_class
    klass = klass.class_for_source(source) if klass.respond_to?(:class_for_source)
    klass
  end

  def self.workflow_class
    @workflow_class ||= self.name.underscore.chomp("_template").gsub(/_request$/, "_workflow").camelize.constantize rescue nil
  end

  def request_task_class
    self.class.request_task_class
  end

  def self.request_task_class
    @request_task_class ||= begin
      case self.name
      when 'MiqProvisionRequest', 'MiqHostProvisionRequest'
        self.name.underscore.chomp('_request').camelize.constantize
      else
        self.name.underscore.gsub(/_request$/, "_task").camelize.constantize
      end
    end
  end

  def requested_task_idx
    self.options[:src_ids]
  end

  def customize_request_task_attributes(req_task_attrs, idx)
    req_task_attrs[:source_id]   = idx
    req_task_attrs[:source_type] = self.class::SOURCE_CLASS_NAME
  end

  def create_request
    self.requester = self.get_user
    return self
  end

  def set_description(force = false)
    if self.description.nil? || force == true
      self.update_attribute(:description, self.request_task_class.get_description(self))
    end
  end

  def update_request_status
    states = Hash.new {|h,k| h[k]=0}
    status = Hash.new {|h,k| h[k]=0}

    task_count = self.miq_request_tasks.count
    self.miq_request_tasks.each do |p|
      states[p.state] += 1
      states[:total] += 1
      status[p.status] += 1
    end
    total = states.delete(:total).to_i
    unknown_state = task_count - total
    states["unknown"] = unknown_state unless unknown_state.zero?
    msg = states.sort.collect {|s| "#{s[0].capitalize} = #{s[1]}"}.join("; ")

    req_state = (states.length == 1) ? states.keys.first : "active"

    # Determine status to report
    req_status = if status.keys.include?('Error')
      'Error'
    elsif status.keys.include?('Timeout')
      'Timeout'
    elsif status.keys.include?('Warn')
      'Warn'
    else
      'Ok'
    end

    if req_state == "finished"
      self.update_attribute(:fulfilled_on, Time.now.utc)
      msg = (req_status == 'Ok') ? "Request complete" : "Request completed with errors"
    end

    # If there is only 1 request_task, set the parent message the same
    if task_count == 1
      child = self.miq_request_tasks.first
      msg = child.message unless child.nil?
    end

    self.update_attributes(:request_state=>req_state, :status=>req_status, :message=>msg)
  end

  def my_zone
    nil
  end

  def my_role
    nil
  end

  def task_check_on_execute
    raise "#{self.class::TASK_DESCRIPTION} request is already being processed" if self.class::ACTIVE_STATES.include?(self.request_state)
    raise "#{self.class::TASK_DESCRIPTION} request has already been processed" if self.request_state == "finished"
    raise "approval is required for #{self.class::TASK_DESCRIPTION}"           unless self.approved?
  end

  def execute
    self.task_check_on_execute

    deliver_on = nil
    if self.get_option(:schedule_type) == "schedule"
      deliver_on = self.get_option(:schedule_time).utc rescue nil
    end

    #self.create_request_tasks
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => "create_request_tasks",
      :zone        => self.my_zone,
      :role        => self.my_role,
      :task_id     => "#{self.class.name.underscore}_#{self.id}",
      :msg_timeout => 3600,
      :deliver_on  => deliver_on
    )
  end

  def create_request_tasks
    log_header = "MIQ(#{self.class.name}.create_request_tasks)"
    $log.info("#{log_header} Creating request task instances for: <#{self.description}>...")

    return if automate_event_failed?("request_starting")

    # Create a MiqRequestTask object for each requested item
    self.update_attribute(:options, self.options.merge!(:delivered_on => Time.now.utc))

    begin
      requested_tasks = self.requested_task_idx
      tasks_requested = requested_tasks.length
      request_task_created = 0
      requested_tasks.each do |idx|
        req_task = self.create_request_task(idx)
        self.miq_request_tasks << req_task
        req_task.deliver_to_automate
        request_task_created += 1
      end
      self.update_request_status

      if tasks_requested == 1
        single_description = self.miq_request_tasks.first.description
        self.update_attribute(:description, single_description)
      end
    rescue
      $log.log_backtrace($!)
      request_state, status = request_task_created.zero? ? ["finished", "Error"] : ["active", "Warn"]
      self.update_attributes(:request_state => request_state, :status => status, :message => "Error: #{$!}")
    end
  end

  def self.new_request_task(attribs)
    request_task_class.new(attribs)
  end

  def create_request_task(idx)
    log_header = "MIQ(#{self.class.name}.create_request_tasks)"

    req_task_attribs = self.attributes.dup
    req_task_attribs['state'] = req_task_attribs.delete('request_state')
    (req_task_attribs.keys - MiqRequestTask.column_names + ['created_on', 'updated_on', 'type']).each {|key| req_task_attribs.delete(key)}
    $log.debug("#{log_header} #{self.class.name} Attributes: [#{req_task_attribs.inspect}]...")

    self.customize_request_task_attributes(req_task_attribs, idx)
    req_task = self.class.new_request_task(req_task_attribs)
    req_task.miq_request = self
    req_task.save!
    req_task.after_request_task_create

    return req_task
  end

  # Helper method when not using workflow
  def self.create_request(values, requester_id, auto_approve, request_type, target_class, event_message)
    values[:src_ids] = values[:src_ids].to_miq_a unless values[:src_ids].nil?
    request = self.create({:options => values, :userid => requester_id, :request_type => request_type})
    request.save!  # Force validation errors to raise now

    request.set_description
    request.create_request

    event_name    = "#{self.name.underscore}_created"
    AuditEvent.success(:event => event_name, :target_class => target_class, :userid => requester_id, :message=> event_message)

    request.call_automate_event_queue("request_created")
    request.approve(requester_id, "Auto-Approved") if auto_approve == true
    return request
  end

  # Helper method when not using workflow
  def self.update_request(request, values, requester_id, target_class, event_message)
    request = request.kind_of?(MiqRequest) ? request : MiqRequest.find(request)
    request.update_attribute(:options, request.options.merge(values))

    event_name    = "#{self.name.underscore}_updated"
    AuditEvent.success(:event => event_name, :target_class => target_class, :userid => requester_id, :message=>event_message)

    request.call_automate_event_queue("request_updated")
    return request
  end

end
