class MiqRequest < ApplicationRecord
  extend InterRegionApiMethodRelay

  ACTIVE_STATES = %w(active queued)

  belongs_to :source,            :polymorphic => true
  belongs_to :destination,       :polymorphic => true
  belongs_to :requester,         :class_name  => "User"
  belongs_to :tenant
  belongs_to :service_order
  has_many   :miq_approvals,     :dependent   => :destroy
  has_many   :miq_request_tasks, :dependent   => :destroy

  alias_attribute :state, :request_state

  serialize   :options, Hash

  default_value_for(:message)       { |r| "#{r.class::TASK_DESCRIPTION} - Request Created" }
  default_value_for :options,       {}
  default_value_for :request_state, 'pending'
  default_value_for(:request_type)  { |r| r.request_types.first }
  default_value_for :status,        'Ok'
  default_value_for :process,       true

  validates_inclusion_of :approval_state, :in => %w(pending_approval approved denied), :message => "should be 'pending_approval', 'approved' or 'denied'"
  validates_inclusion_of :status,         :in => %w(Ok Warn Error Timeout Denied)

  validate :validate_class, :validate_request_type

  include TenancyMixin

  virtual_column  :reason,               :type => :string,   :uses => :miq_approvals
  virtual_column  :v_approved_by,        :type => :string,   :uses => :miq_approvals
  virtual_column  :v_approved_by_email,  :type => :string,   :uses => {:miq_approvals => :stamper}
  virtual_column  :stamped_on,           :type => :datetime, :uses => :miq_approvals
  virtual_column  :request_type_display, :type => :string
  virtual_column  :resource_type,        :type => :string
  virtual_column  :state,                :type => :string

  before_validation :initialize_attributes, :on => :create

  include MiqRequestMixin

  MODEL_REQUEST_TYPES = {
    :Service        => {
      :MiqProvisionRequest                 => {
        :template          => N_("VM Provision"),
        :clone_to_vm       => N_("VM Clone"),
        :clone_to_template => N_("VM Publish"),
      },
      :MiqProvisionConfiguredSystemRequest => {
        :provision_via_foreman => N_("%{config_mgr_type} Provision") % {:config_mgr_type => ui_lookup(:ui_title => 'foreman')}
      },
      :VmReconfigureRequest                => {
        :vm_reconfigure => N_("VM Reconfigure")
      },
      :VmMigrateRequest                    => {
        :vm_migrate => N_("VM Migrate")
      },
      :ServiceTemplateProvisionRequest     => {
        :clone_to_service => N_("Service Provision")
      },
      :ServiceReconfigureRequest           => {
        :service_reconfigure => N_("Service Reconfigure")
      }
    },
    :Infrastructure => {
      :MiqHostProvisionRequest => {
        :host_pxe_install => N_("Host Provision")
      },
    },
    :Automate       => {
      :AutomationRequest => {
        :automation => N_("Automation")
      }
    }
  }

  REQUEST_TYPES_BACKEND_ONLY = {:MiqProvisionRequestTemplate => {:template => "VM Provision Template"}}
  REQUEST_TYPES = MODEL_REQUEST_TYPES.values.each_with_object(REQUEST_TYPES_BACKEND_ONLY) { |i, h| i.each { |k, v| h[k] = v } }
  REQUEST_TYPE_TO_MODEL = MODEL_REQUEST_TYPES.values.each_with_object({}) do |i, h|
    i.each { |k, v| v.keys.each { |vk| h[vk] = k } }
  end


  delegate :deny, :reason, :stamped_on, :to => :first_approval
  delegate :userid, :to => :requester, :prefix => true
  delegate :request_task_class, :request_types, :task_description, :to => :class

  def self.class_from_request_data(data)
    request_type = (data[:__request_type__] || data[:request_type]).try(:to_sym)
    model_symbol = REQUEST_TYPE_TO_MODEL[request_type] || raise(ArgumentError, "Invalid request_type")
    model_symbol.to_s.constantize
  end

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
    self.approval_state ||= "pending_approval"
    miq_approvals << build_default_approval if miq_approvals.empty?

    return unless requester
    self.requester_name ||= requester.name
    self.userid         ||= requester.userid
    self.tenant         ||= requester.current_tenant
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

  def must_have_user
    errors.add(:userid, "must have valid user") unless requester
  end

  def call_automate_event_queue(event_name)
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "call_automate_event",
      :args        => [event_name],
      :zone        => options.fetch(:miq_zone, my_zone),
      :msg_timeout => 3600
    )
  end

  def build_request_event(event_name)
    event_obj = RequestEvent.create(
      :event_type => event_name,
      :target     => self,
      :source     => 'Request'
    )

    {'EventStream::event_stream' => event_obj.id,
     :event_stream_id            => event_obj.id
    }
  end

  def call_automate_event(event_name)
    _log.info("Raising event [#{event_name}] to Automate")
    MiqAeEvent.raise_evm_event(event_name, self, build_request_event(event_name))
    _log.info("Raised  event [#{event_name}] to Automate")
  rescue MiqAeException::Error => err
    message = _("Error returned from %{name} event processing in Automate: %{error_message}") %
                {:name => event_name, :error_message => err.message}
    raise
  end

  def call_automate_event_sync(event_name)
    _log.info("Raising event [#{event_name}] to Automate synchronously")
    ws = MiqAeEvent.raise_evm_event(event_name, self, build_request_event(event_name), :synchronous => true)
    _log.info("Raised event [#{event_name}] to Automate")
    return ws
  rescue MiqAeException::Error => err
    message = _("Error returned from %{name} event processing in Automate: %{error_message}") %
                {:name => event_name, :error_message => err.message}
    raise
  end

  def automate_event_failed?(event_name)
    ws = call_automate_event_sync(event_name)

    if ws.nil?
      _log.warn("Aborting because Automate failed for event <#{event_name}>")
      return true
    end

    if ws.root['ae_result'] == 'error'
      _log.warn("Aborting because Automate returned ae_result=<#{ws.root['ae_result']}> for event <#{event_name}>")
      return true
    end

    false
  end

  def pending
    call_automate_event_queue("request_pending")
  end

  def approval_approved
    unless self.approved?
      _log.info("Request: [#{description}] has outstanding approvals")
      return false
    end

    update_attributes(:approval_state => "approved")
    call_automate_event_queue("request_approved")

    # execute parent now that request is approved
    _log.info("Request: [#{description}] has all approvals approved, proceeding with execution")
    begin
      execute
    rescue => err
      _log.error("#{err.message}, attempting to execute request: [#{description}]")
      _log.error(err.backtrace.join("\n"))
    end

    true
  end

  def approval_denied
    update_attributes(:approval_state => "denied", :request_state => "finished", :status => "Denied")
    call_automate_event_queue("request_denied")
  end

  def approved?
    miq_approvals.all? { |a| a.state == "approved" }
  end

  def v_approved_by
    miq_approvals.collect(&:stamper_name).compact.join(", ")
  end

  def v_approved_by_email
    emails = miq_approvals.inject([]) { |arr, a| arr << a.stamper.email unless a.stamper.nil? || a.stamper.email.nil?; arr }
    emails.join(", ")
  end

  def get_options
    options || {}
  end

  def request_type_display
    request_type.nil? ? "Unknown" : REQUEST_TYPES.fetch_path(type.to_sym, request_type.to_sym)
  end

  def self.request_types
    REQUEST_TYPES[name.to_sym].keys.collect(&:to_s)
  end

  def request_status
    return status if self.approval_state == 'approved' && !status.nil?
    case self.approval_state
    when 'pending_approval' then 'Unknown'
    when 'denied'           then 'Error'
    else 'Unknown'
    end
  end

  def build_default_approval
    MiqApproval.new(:description => "Default Approval")
  end

  # TODO: Helper methods to support UI in legacy mode - single approval by role
  #       These should be removed once multi-approver is fully supported.
  def first_approval
    miq_approvals.first || build_default_approval
  end

  def approve(userid, reason)
    first_approval.approve(userid, reason) unless self.approved?
  end
  api_relay_method(:approve) { |_userid, reason| {:reason => reason} }
  api_relay_method(:deny)    { |_userid, reason| {:reason => reason} }

  def stamped_by
    first_approval.stamper.try(:userid)
  end

  def approver
    first_approval.approver.try(:name)
  end
  alias_method :approver_role, :approver  # TODO: Is this needed anymore?

  def workflow_class
    klass = self.class.workflow_class
    klass = klass.class_for_source(source) if klass.respond_to?(:class_for_source)
    klass
  end

  def self.workflow_class
    @workflow_class ||= name.underscore.chomp("_template").gsub(/_request$/, "_workflow").camelize.constantize rescue nil
  end

  def self.request_task_class
    @request_task_class ||= begin
      case name
      when 'MiqProvisionRequest', 'MiqHostProvisionRequest'
        name.underscore.chomp('_request').camelize.constantize
      else
        name.underscore.gsub(/_request$/, "_task").camelize.constantize
      end
    end
  end

  def requested_task_idx
    options[:src_ids]
  end

  def customize_request_task_attributes(req_task_attrs, idx)
    req_task_attrs[:source_id]   = idx
    req_task_attrs[:source_type] = self.class::SOURCE_CLASS_NAME
  end

  def create_request
    self
  end

  def set_description(force = false)
    if description.nil? || force == true
      description = default_description || request_task_class.get_description(self)
      update_attributes(:description => description)
    end
  end

  def update_request_status
    states = Hash.new { |h, k| h[k] = 0 }
    status = Hash.new { |h, k| h[k] = 0 }

    task_count = miq_request_tasks.count
    miq_request_tasks.each do |p|
      states[p.state] += 1
      states[:total] += 1
      status[p.status] += 1
    end
    total = states.delete(:total).to_i
    unknown_state = task_count - total
    states["unknown"] = unknown_state unless unknown_state.zero?
    msg = states.sort.collect { |s| "#{s[0].capitalize} = #{s[1]}" }.join("; ")

    req_state = (states.length == 1) ? states.keys.first : "active"

    # Determine status to report
    req_status = status.slice('Error', 'Timeout', 'Warn').keys.first || 'Ok'

    if req_state == "finished"
      update_attribute(:fulfilled_on, Time.now.utc)
      msg = (req_status == 'Ok') ? "Request complete" : "Request completed with errors"
    end

    # If there is only 1 request_task, set the parent message the same
    if task_count == 1
      child = miq_request_tasks.first
      msg = child.message unless child.nil?
    end

    update_attributes(:request_state => req_state, :status => req_status, :message => display_message(msg))
  end

  def post_create_request_tasks
  end

  def my_zone
    MiqServer.my_zone
  end

  def my_role
    nil
  end

  def task_check_on_execute
    if self.class::ACTIVE_STATES.include?(request_state)
      raise _("%{task} request is already being processed") % {:task => self.class::TASK_DESCRIPTION}
    end
    if request_state == "finished"
      raise _("%{task} request has already been processed") % {:task => self.class::TASK_DESCRIPTION}
    end
    raise _("approval is required for %{task}") % {:task => self.class::TASK_DESCRIPTION} unless approved?
  end

  def execute
    task_check_on_execute

    deliver_on = nil
    if get_option(:schedule_type) == "schedule"
      deliver_on = get_option(:schedule_time).utc rescue nil
    end

    # self.create_request_tasks
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "create_request_tasks",
      :zone        => options.fetch(:miq_zone, my_zone),
      :role        => my_role,
      :task_id     => "#{self.class.name.underscore}_#{id}",
      :msg_timeout => 3600,
      :deliver_on  => deliver_on
    )
  end

  def create_request_tasks
    _log.info("Creating request task instances for: <#{description}>...")

    return if automate_event_failed?("request_starting")

    # Create a MiqRequestTask object for each requested item
    update_attribute(:options, options.merge!(:delivered_on => Time.now.utc))

    begin
      requested_tasks = requested_task_idx
      request_task_created = 0
      requested_tasks.each do |idx|
        req_task = create_request_task(idx)
        miq_request_tasks << req_task
        req_task.deliver_to_automate
        request_task_created += 1
      end
      update_request_status
      post_create_request_tasks
    rescue
      _log.log_backtrace($ERROR_INFO)
      request_state, status = request_task_created.zero? ? %w(finished Error) : %w(active Warn)
      update_attributes(:request_state => request_state, :status => status, :message => "Error: #{$ERROR_INFO}")
    end
  end

  def self.new_request_task(attribs)
    request_task_class.new(attribs)
  end

  def create_request_task(idx)
    req_task_attribs = attributes.dup
    (req_task_attribs.keys - MiqRequestTask.column_names + %w(id state created_on updated_on type)).each { |key| req_task_attribs.delete(key) }
    _log.debug("#{self.class.name} Attributes: [#{req_task_attribs.inspect}]...")

    customize_request_task_attributes(req_task_attribs, idx)
    req_task = self.class.new_request_task(req_task_attribs)
    req_task.miq_request = self

    yield req_task if block_given?

    req_task.save!
    req_task.after_request_task_create

    req_task
  end

  # Helper method when not using workflow
  def self.make_request(request, values, requester, auto_approve = false)
    if request
      update_request(request, values, requester)
    else
      create_request(values, requester, auto_approve)
    end
  end

  def self.create_request(values, requester, auto_approve = false)
    values[:src_ids] = values[:src_ids].to_miq_a unless values[:src_ids].nil?
    request_type = values.delete(:__request_type__) || request_types.first
    request = create!(:options => values, :requester => requester, :request_type => request_type)

    request.post_create(auto_approve)
  end
  api_relay_class_method(:create_request, :create) do |values, requester, auto_approve|
    [
      find_source_id_from_values(values),
      {
        :options      => values,
        :requester    => {"user_name" => requester.userid},
        :auto_approve => auto_approve
      }
    ]
  end

  def self.find_source_id_from_values(values)
    MiqRequestMixin.get_option(:src_vm_id, nil, values) ||
      MiqRequestMixin.get_option(:src_id, nil, values) ||
      MiqRequestMixin.get_option(:src_ids, nil, values)
  end
  private_class_method :find_source_id_from_values

  def post_create(auto_approve)
    set_description

    log_request_success(requester, :created)

    if process_on_create?
      call_automate_event_queue("request_created")
      approve(requester, "Auto-Approved") if auto_approve
      reload if auto_approve
    end

    self
  end

  # Helper method when not using workflow
  def self.update_request(request, values, requester)
    request = request.kind_of?(MiqRequest) ? request : MiqRequest.find(request)
    request.update_request(values, requester)
  end

  def update_request(values, requester)
    update_attribute(:options, options.merge(values))
    set_description(true)

    log_request_success(requester, :updated)

    call_automate_event_queue("request_updated")
    self
  end
  api_relay_method(:update_request, :edit) do |values, requester|
    {
      :options   => values,
      :requester => {"user_name" => requester.userid}
    }
  end

  def log_request_success(requester_id, mode)
    requester_id = requester_id.userid if requester_id.respond_to?(:userid)
    status_message = mode == :created ? "requested" : "request updated"
    event_message = "#{self.class::TASK_DESCRIPTION} #{status_message} by <#{requester_id}> for #{my_records}"

    AuditEvent.success(
      :event        => event_name(mode),
      :target_class => self.class::SOURCE_CLASS_NAME,
      :userid       => requester_id,
      :message      => event_message,
    )
  end

  def event_name(mode)
    "#{self.class.name.underscore}_#{mode}"
  end

  def process_on_create?
    true
  end

  def request_pending_approval?
    approval_state == "pending_approval"
  end

  def request_approved?
    approval_state == "approved"
  end

  def request_denied?
    approval_state == "denied"
  end

  def my_records
    "#{self.class::SOURCE_CLASS_NAME}:#{requested_task_idx.inspect}"
  end

  private

  def default_description
  end

  def validate_class
    errors.add(:type, "should be a descendant of MiqRequest") if instance_of?(MiqRequest)
  end

  def validate_request_type
    errors.add(:request_type, "should be #{request_types.join(", ")}") unless request_types.include?(request_type)
  end
end
