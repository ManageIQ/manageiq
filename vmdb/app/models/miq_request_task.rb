class MiqRequestTask < ActiveRecord::Base
  include_concern 'Dumping'
  include_concern 'PostInstallCallback'
  include_concern 'StateMachine'

  belongs_to :miq_request
  belongs_to :source,            :polymorphic => true
  belongs_to :destination,       :polymorphic => true
  has_many   :miq_request_tasks, :dependent   => :destroy
  belongs_to :miq_request_task

  serialize   :phase_context, Hash
  serialize   :options,       Hash

  default_value_for :phase_context, {}
  default_value_for :options,       {}

  validates_inclusion_of :status, :in => %w{ Ok Warn Error Timeout }

  include MiqRequestMixin

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
    upd_attr[:message] = upd_attr[:message][0, 255] if upd_attr.has_key?(:message)
    self.update_attributes!(upd_attr)

    # If this request has a miq_request_task parent use that, otherwise the parent is the miq_request
    parent = miq_request_task.nil? ? miq_request(true) : miq_request_task(true)
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
      msg = (req_status == 'Ok') ? "Task complete" : "Task completed with errors"
    end

    # If there is only 1 request_task, set the parent message the same
    if task_count == 1
      child = child_requests.first
      msg = child.message unless child.nil?
    end

    update_and_notify_parent(:state => req_state, :status => req_status, :message => display_message(msg))
  end

  def execute_callback(state, message, result)
    unless state.to_s.downcase == "ok"
      update_and_notify_parent(:state => "finished", :status => "Error", :message => "Error: #{message}")
    end
  end

  def request_class
    self.class.request_class
  end

  def self.request_class
    if self.is_or_subclass_of?(MiqProvision)
      MiqProvisionRequest
    elsif self.is_or_subclass_of?(MiqHostProvision)
      MiqHostProvisionRequest
    else
      name.underscore.gsub(/_task$/, "_request").camelize.constantize
    end
  end

  def self.task_description
    request_class::TASK_DESCRIPTION
  end

  def task_description
    self.class.task_description
  end

  def get_description
    self.class.get_description(self)
  end

  def task_check_on_execute
    raise "#{request_class::TASK_DESCRIPTION} request is already being processed" if request_class::ACTIVE_STATES.include?(state)
    raise "#{request_class::TASK_DESCRIPTION} request has already been processed" if state == "finished"
    raise "approval is required for #{request_class::TASK_DESCRIPTION}"           unless self.approved?
  end

  def deliver_to_automate(req_type = request_type, zone = nil)
    log_header = "MIQ(#{self.class.name}.deliver_to_automate)"
    task_check_on_execute

    $log.info("#{log_header} Queuing #{request_class::TASK_DESCRIPTION}: [#{description}]...")

    if self.class::AUTOMATE_DRIVES
      args = {}
      args[:object_type]   = self.class.name
      args[:object_id]     = id
      args[:attrs]         = {"request" => req_type}
      args[:instance_name] = "AUTOMATION"
      args[:user_id]       = get_user.id

      zone ||= source.respond_to?(:my_zone) ? source.my_zone : MiqServer.my_zone
      MiqQueue.put(
        :class_name  => 'MiqAeEngine',
        :method_name => 'deliver',
        :args        => [args],
        :role        => 'automate',
        :zone        => options.fetch(:miq_zone, zone),
        :task_id     => my_task_id,
      )
      update_and_notify_parent(:state => "pending", :status => "Ok",  :message => "Automation Starting")
    else
      execute_queue
    end
  end

  def execute_queue(queue_options = {})
    log_header = "MIQ(#{self.class.name}.execute_queue)"
    task_check_on_execute

    $log.info("#{log_header} Queuing #{request_class::TASK_DESCRIPTION}: [#{description}]...")

    deliver_on = nil
    if get_option(:schedule_type) == "schedule"
      deliver_on = get_option(:schedule_time).utc rescue nil
    end

    zone = source.respond_to?(:my_zone) ? source.my_zone : MiqServer.my_zone

    queue_options.reverse_merge!(
      :class_name   => self.class.name,
      :instance_id  => id,
      :method_name  => "execute",
      :zone         => options.fetch(:miq_zone, zone),
      :role         => miq_request.my_role,
      :task_id      => my_task_id,
      :deliver_on   => deliver_on,
      :miq_callback => {:class_name => self.class.name, :instance_id => id, :method_name => :execute_callback}
    )
    MiqQueue.put(queue_options)

    update_and_notify_parent(:state => "queued", :status => "Ok", :message => "State Machine Initializing")
  end

  def execute
    log_header = "MIQ(#{self.class.name}.execute)"

    $log.info("#{log_header} Executing #{request_class::TASK_DESCRIPTION} request: [#{description}]")
    update_and_notify_parent(:state => "active", :status => "Ok", :message => "In Process")

    begin
      message = "#{request_class::TASK_DESCRIPTION} initiated"
      $log.info("#{log_header} #{message}")
      update_and_notify_parent(:message => message)

      # Process the request
      do_request

    rescue => err
      message = "Error: #{err.message}"
      $log.error("#{log_header} [#{message}] encountered during #{request_class::TASK_DESCRIPTION}")
      $log.log_backtrace(err)
      update_and_notify_parent(:state => "finished", :status => "Error", :message => message)
      return
    end
  end

  private

  def validate_request_type
    errors.add(:request_type, "should be #{request_class::REQUEST_TYPES.join(", ")}") unless request_class::REQUEST_TYPES.include?(request_type)
  end

  def validate_state
    errors.add(:state, "should be #{valid_states.join(", ")}") unless valid_states.include?(state)
  end

  def valid_states
    %w(pending finished) + request_class::ACTIVE_STATES
  end
end
