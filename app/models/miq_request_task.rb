class MiqRequestTask < ApplicationRecord
  include_concern 'Dumping'
  include_concern 'PostInstallCallback'
  include_concern 'StateMachine'

  belongs_to :miq_request
  belongs_to :source,            :polymorphic => true
  belongs_to :destination,       :polymorphic => true
  has_many   :miq_request_tasks, :dependent   => :destroy
  belongs_to :miq_request_task
  belongs_to :tenant

  serialize   :phase_context, Hash
  serialize   :options,       Hash

  default_value_for :phase_context, {}
  default_value_for :options,       {}
  default_value_for :state,         'pending'
  default_value_for :status,        'Ok'

  delegate :request_class, :task_description, :to => :class

  validates_inclusion_of :status, :in => %w( Ok Warn Error Timeout )

  include MiqRequestMixin
  include TenancyMixin

  CANCEL_STATUS_REQUESTED  = "cancel_requested".freeze
  CANCEL_STATUS_PROCESSING = "canceling".freeze
  CANCEL_STATUS_FINISHED   = "canceled".freeze
  CANCEL_STATUS            = [CANCEL_STATUS_REQUESTED, CANCEL_STATUS_PROCESSING, CANCEL_STATUS_FINISHED].freeze

  validates :cancelation_status, :inclusion => { :in        => CANCEL_STATUS,
                                                 :allow_nil => true,
                                                 :message   => "should be one of #{CANCEL_STATUS.join(", ")}" }

  def approved?
    if miq_request.class.name.include?('Template') && miq_request_task
      miq_request_task.miq_request.approved?
    else
      miq_request.approved?
    end
  end

  def after_request_task_create
  end

  def update_and_notify_parent(upd_attr)
    upd_attr[:message] = upd_attr[:message][0, 255] if upd_attr.key?(:message)
    update!(upd_attr)

    # If this request has a miq_request_task parent use that, otherwise the parent is the miq_request
    parent = miq_request_task || miq_request
    parent.reload
    parent.update_request_status
  end

  def update_request_status
    states = Hash.new { |h, k| h[k] = 0 }
    status = Hash.new { |h, k| h[k] = 0 }

    child_requests = miq_request_tasks
    task_count = child_requests.size
    child_requests.each do |child_req|
      states[child_req.state] += 1
      states[:total] += 1
      status[child_req.status] += 1
    end
    total = states.delete(:total).to_i
    unknown_state = task_count - total
    states["unknown"] = unknown_state unless unknown_state.zero?
    msg = states.sort.collect { |s| "#{s[0].capitalize} = #{s[1]}" }.join("; ")

    req_state = (states.length == 1) ? states.keys.first : "active"

    # Determine status to report
    req_status = status.slice('Error', 'Timeout', 'Warn').keys.first || 'Ok'

    if req_state == "finished" && state != "finished"
      req_state = req_status == 'Ok' ? completed_state : "finished"
      $log.info("Child tasks finished but current task still processing. Setting state to: [#{req_state}]...")
    end

    if req_state == "finished"
      msg = (req_status == 'Ok') ? "Task complete" : "Task completed with errors"
    end

    # If there is only 1 request_task, set the parent message the same
    if task_count == 1
      child = child_requests.first
      msg = child.message unless child.nil?
    end

    update_and_notify_parent(:state => req_state, :status => req_status, :message => display_message(msg))
  end

  def completed_state
    "provisioned"
  end

  def execute_callback(state, message, _result)
    unless state.to_s.downcase == "ok"
      update_and_notify_parent(:state => "finished", :status => "Error", :message => "Error: #{message}")
    end
  end

  def self.request_class
    if self <= MiqProvision
      MiqProvisionRequest
    else
      name.underscore.gsub(/_task$/, "_request").camelize.constantize
    end
  end

  def self.task_description
    request_class::TASK_DESCRIPTION
  end

  def get_description
    self.class.get_description(self)
  end

  def task_check_on_delivery
    if request_class::ACTIVE_STATES.include?(state)
      raise _("%{task} request is already being processed") % {:task => request_class::TASK_DESCRIPTION}
    end
    task_check_on_execute
  end

  def task_check_on_execute
    if state == "finished"
      raise _("%{task} request has already been processed") % {:task => request_class::TASK_DESCRIPTION}
    end
    raise _("approval is required for %{task}") % {:task => request_class::TASK_DESCRIPTION} unless approved?
  end

  def deliver_to_automate(req_type = request_type, zone = nil)
    task_check_on_delivery

    _log.info("Queuing #{request_class::TASK_DESCRIPTION}: [#{description}]...")

    if self.class::AUTOMATE_DRIVES
      args = {
        :object_type   => self.class.name,
        :object_id     => id,
        :attrs         => {"request" => req_type},
        :instance_name => "AUTOMATION",
        :user_id       => get_user.id,
        :miq_group_id  => get_user.current_group.id,
        :tenant_id     => get_user.current_tenant.id,
      }

      zone ||= source.respond_to?(:my_zone) ? source.my_zone : MiqServer.my_zone
      MiqQueue.put(
        :class_name     => 'MiqAeEngine',
        :method_name    => 'deliver',
        :args           => [args],
        :role           => 'automate',
        :zone           => options.fetch(:miq_zone, zone),
        :tracking_label => tracking_label_id,
      )
      update_and_notify_parent(:state => "pending", :status => "Ok",  :message => "Automation Starting")
    else
      execute_queue
    end
  end

  def execute_queue(queue_options = {})
    task_check_on_execute

    _log.info("Queuing #{request_class::TASK_DESCRIPTION}: [#{description}]...")

    deliver_on = nil
    if get_option(:schedule_type) == "schedule"
      deliver_on = get_option(:schedule_time).utc rescue nil
    end

    zone = source.respond_to?(:my_zone) ? source.my_zone : MiqServer.my_zone

    queue_options.reverse_merge!(
      :class_name     => self.class.name,
      :instance_id    => id,
      :method_name    => "execute",
      :zone           => options.fetch(:miq_zone, zone),
      :role           => miq_request.my_role,
      :queue_name     => miq_request.my_queue_name,
      :tracking_label => tracking_label_id,
      :deliver_on     => deliver_on,
      :miq_callback   => {:class_name => self.class.name, :instance_id => id, :method_name => :execute_callback}
    )
    MiqQueue.put(queue_options)

    update_and_notify_parent(:state => "queued", :status => "Ok", :message => "State Machine Initializing")
  end

  def execute
    _log.info("Executing #{request_class::TASK_DESCRIPTION} request: [#{description}]")
    update_and_notify_parent(:state => "active", :status => "Ok", :message => "In Process")

    begin
      message = "#{request_class::TASK_DESCRIPTION} initiated"
      _log.info(message)
      update_and_notify_parent(:message => message)

      # Process the request
      do_request

    rescue => err
      message = "Error: #{err.message}"
      _log.error("[#{message}] encountered during #{request_class::TASK_DESCRIPTION}")
      _log.log_backtrace(err)
      update_and_notify_parent(:state => "finished", :status => "Error", :message => message)
      return
    end
  end

  def self.display_name(number = 1)
    n_('Request Task', 'Request Tasks', number)
  end

  def cancel
    raise _("Cancel operation is not supported for %{class}") % {:class => self.class.name}
  end

  def cancel_requested?
    cancelation_status == MiqRequestTask::CANCEL_STATUS_REQUESTED
  end

  def canceling?
    cancelation_status == MiqRequestTask::CANCEL_STATUS_PROCESSING
  end

  def canceled?
    cancelation_status == MiqRequestTask::CANCEL_STATUS_FINISHED
  end

  private

  def validate_request_type
    errors.add(:request_type, "should be #{request_class.request_types.join(", ")}") unless request_class.request_types.include?(request_type)
  end

  def validate_state
    errors.add(:state, "should be #{valid_states.join(", ")}") unless valid_states.include?(state)
  end

  def valid_states
    %w(pending finished) + request_class::ACTIVE_STATES
  end
end
