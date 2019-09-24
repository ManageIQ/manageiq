class MiqTask < ApplicationRecord
  include_concern 'Purging'

  serialize :context_data
  STATE_INITIALIZED = 'Initialized'.freeze
  STATE_QUEUED      = 'Queued'.freeze
  STATE_ACTIVE      = 'Active'.freeze
  STATE_FINISHED    = 'Finished'.freeze

  STATUS_OK         = 'Ok'.freeze
  STATUS_WARNING    = 'Warn'.freeze
  STATUS_ERROR      = 'Error'.freeze
  STATUS_TIMEOUT    = 'Timeout'.freeze
  STATUS_EXPIRED    = 'Expired'.freeze
  STATUS_UNKNOWN    = 'Unknown'.freeze

  HUMAN_STATUS      = {
    STATE_INITIALIZED => STATE_INITIALIZED,
    STATE_QUEUED      => STATE_QUEUED,
    STATE_ACTIVE      => 'Running'.freeze,
    STATUS_OK         => 'Complete'.freeze,
    STATUS_WARNING    => 'Finished with Warnings'.freeze,
    STATUS_ERROR      => STATUS_ERROR,
    STATUS_TIMEOUT    => 'Timed Out'.freeze
  }.freeze

  DEFAULT_MESSAGE   = 'Initialized'.freeze
  DEFAULT_USERID    = 'system'.freeze

  MESSAGE_TASK_COMPLETED_SUCCESSFULLY   = 'Task completed successfully'.freeze
  MESSAGE_TASK_COMPLETED_UNSUCCESSFULLY = 'Task did not complete successfully'.freeze

  has_one :log_file, :dependent => :destroy
  has_one :binary_blob, :as => :resource, :dependent => :destroy
  has_one :miq_report_result
  has_one :job, :dependent => :destroy
  has_one :miq_queue

  belongs_to :miq_server

  before_validation :initialize_attributes, :on => :create

  before_destroy :check_active, :check_associations
  before_save :ensure_started

  virtual_has_one :task_results
  virtual_attribute :state_or_status, :string, :arel => (lambda do |t|
    t.grouping(Arel::Nodes::Case.new(t[:state]).when(STATE_FINISHED).then(t[:status]).else(t[:state]))
  end)

  scope :active,                  ->           { where(:state => STATE_ACTIVE) }
  scope :no_associated_job,       ->           { where.not("id IN (SELECT miq_task_id from jobs)") }
  scope :timed_out,               ->           { where("updated_on < ?", Time.now.utc - ::Settings.task.active_task_timeout.to_i_with_method) }
  scope :with_userid,             ->(userid)   { where(:userid => userid) }
  scope :with_zone,               ->(zone)     { where(:zone => zone) }
  scope :with_updated_on_between, ->(from, to) { where("miq_tasks.updated_on BETWEEN ? AND ?", from, to) }
  scope :with_state,              ->(state)    { where(:state => state) }
  scope :finished,                ->           { with_state('Finished') }
  scope :running,                 ->           { where.not(:state => %w(Finished Waiting_to_start Queued)) }
  scope :queued,                  ->           { with_state(%w(Waiting_to_start Queued)) }
  scope :completed_ok,            ->           { finished.where(:status => 'Ok') }
  scope :completed_warn,          ->           { finished.where(:status => 'Warn') }
  scope :completed_error,         ->           { finished.where(:status => 'Error') }
  scope :no_status_selected,      ->           { running.where.not(:status => %(Ok Error Warn)) }
  scope :with_status_in,          ->(s, *rest) { rest.reduce(MiqTask.send(s)) { |chain, r| chain.or(MiqTask.send(r)) } }

  def ensure_started
    self.started_on ||= Time.now.utc if state == STATE_ACTIVE
  end

  def self.update_status_for_timed_out_active_tasks
    MiqTask.active.timed_out.no_associated_job.find_each do |task|
      task.update_status(STATE_FINISHED, STATUS_ERROR,
                         "Task [#{task.id}] timed out - not active for more than #{::Settings.task.active_task_timeout.to_i_with_method} seconds")
    end
  end

  def active?
    ![STATE_QUEUED, STATE_FINISHED].include?(state)
  end

  def check_active
    if active?
      _log.warn("Task is active, delete not allowed; id: [#{id}]")
      throw :abort
    end
    _log.info("Task deleted; id: [#{id}]")
    true
  end

  def self.status_ok?(status)
    status.casecmp(STATUS_OK) == 0
  end

  def self.status_error?(status)
    status.casecmp(STATUS_ERROR) == 0
  end

  def self.status_timeout?(status)
    status.casecmp(STATUS_TIMEOUT) == 0
  end

  def self.update_status(taskid, state, status, message)
    task = find_by(:id => taskid)
    task.update_status(state, status, message) unless task.nil?
  end

  def status_ok?
    self.class.status_ok?(status)
  end

  def status_error?
    self.class.status_error?(status)
  end

  def status_timeout?
    self.class.status_timeout?(status)
  end

  def check_associations
    if job && job.is_active?
      _log.warn("Delete not allowed: Task [#{id}] has active job - id: [#{job.id}], guid: [#{job.guid}],")
      throw :abort
    end
    true
  end

  def update_status(state, status, message)
    status = STATUS_ERROR if status == STATUS_EXPIRED
    _log.info("Task: [#{id}] [#{state}] [#{status}] [#{message}]")
    self.status = status
    self.message = message
    self.state = state
    self.miq_server ||= MiqServer.my_server

    save!
  end

  def self.update_message(taskid, message)
    task = find_by(:id => taskid)
    task.update_message(message) unless task.nil?
  end

  def update_message(message)
    _log.info("Task: [#{id}] [#{message}]")
    update!(:message => message)
  end

  def update_context(context)
    update!(:context_data => context)
  end

  def message=(message)
    super(message)
  end

  def self.info(taskid, message, pct_complete)
    task = find_by(:id => taskid)
    task.info(message, pct_complete) unless task.nil?
  end

  def info(message, pct_complete)
    update(:message => message, :pct_complete => pct_complete, :status => STATUS_OK)
  end

  def warn(message)
    update(:message => message, :status => STATUS_WARNING)
  end

  def self.warn(taskid, message)
    task = find_by(:id => taskid)
    task.warn(message) unless task.nil?
  end

  def error(message)
    update(:message => message, :status => STATUS_ERROR)
  end

  def self.error(taskid, message)
    task = find_by(:id => taskid)
    task.error(message) unless task.nil?
  end

  def self.state_initialized(taskid)
    task = find_by(:id => taskid)
    task.state_initialized unless task.nil?
  end

  def state_initialized
    update(:state => STATE_INITIALIZED)
  end

  def self.state_queued(taskid)
    task = find_by(:id => taskid)
    task.state_queued unless task.nil?
  end

  def state_queued
    update(:state => STATE_QUEUED)
  end

  def self.state_active(taskid)
    task = find_by(:id => taskid)
    task.state_active unless task.nil?
  end

  def state_active
    self.state = STATE_ACTIVE
    self.miq_server ||= MiqServer.my_server

    save!
  end

  def self.state_finished(taskid)
    task = find_by(:id => taskid)
    task.state_finished unless task.nil?
  end

  def state_finished
    update(:state => STATE_FINISHED)
  end

  def state_or_status
    state == STATE_FINISHED ? status : state
  end

  def human_status
    self.class.human_status(state_or_status)
  end

  def results_ready?
    status == STATUS_OK && !task_results.blank?
  end

  def queue_callback(state, status, message, result)
    if status.casecmp(STATUS_OK) == 0
      message = MESSAGE_TASK_COMPLETED_SUCCESSFULLY
    else
      message = MESSAGE_TASK_COMPLETED_UNSUCCESSFULLY if message.blank?
    end

    self.task_results = result unless result.nil?
    update_status(state, status.titleize, message)
  end

  def queue_callback_on_exceptions(state, status, message, result)
    # Only callback if status is not "ok"
    unless status.casecmp(STATUS_OK) == 0
      self.task_results = result unless result.nil?
      update_status(state, STATUS_ERROR, message)
    end
  end

  def task_results
    # support legacy task that saved results in the results column
    return Marshal.load(Base64.decode64(results.split("\n").join)) unless results.nil?
    return miq_report_result.report_results unless miq_report_result.nil?
    unless binary_blob.nil?
      serializer_name = binary_blob.data_type
      serializer_name = "Marshal" unless serializer_name == "YAML" # YAML or Marshal, for now
      serializer = serializer_name.constantize
      result = serializer.load(binary_blob.binary)
      return result.kind_of?(String) ? result.force_encoding("UTF-8") : result
    end
    nil
  end

  def task_results=(value)
    value = value.force_encoding("UTF-8") if value.kind_of?(String)
    self.binary_blob   = BinaryBlob.new(:name => "task_results", :data_type => "YAML")
    binary_blob.binary = YAML.dump(value)
  end

  # Create an MiqQueue object with an associated MiqTask object as its callback.
  # Returns the ID of the generated task, or the full task object if the
  # +return_task_object+ argument is set to true.
  #
  # Pre-reqs:
  #
  # The +options+ hash must contain the following required keys:
  #
  #   :name   => the human friendly name of the action to be run
  #   :userid => the user this is being run for, i.e the logged on user who invoked the action in the UI
  #
  # You may alternatively specify :action instead of :name. All other options
  # are passed through the task.
  #
  # The +queue_options+ is a hash containing the following required keys:
  #
  #   :class_name
  #   :method_name
  #   :args
  #
  # The +queue_options+ keys that are not required but may be needed:
  #
  #   :instance_id (if using an instance method...an id)
  #   :queue_name (which queue, priority?)
  #   :zone (zone of the request)
  #   :guid (guid of the server to run the action)
  #   :role (role of the server to run the action)
  #   :msg_timeout => how long you want to wait before pulling the plug on the action (seconds)
  #
  def self.generic_action_with_callback(options, queue_options, return_task_object = false)
    options[:name] ||= options.delete(:action) # Backwards compatibility

    msg = "Queued the action: [#{options[:name]}] being run for user: [#{options[:userid]}]"
    options = {:state => STATE_QUEUED, :status => STATUS_OK, :message => msg}.merge(options)

    task = MiqTask.create(options)

    # Set the callback for this task to set the status based on the results of the actions
    queue_options[:miq_callback] = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback, :args => ['Finished']}
    queue_options[:miq_task_id] = task.id
    method_opts = queue_options[:args].first
    method_opts[:task_id] = task.id if method_opts.kind_of?(Hash)

    MiqQueue.put(queue_options)

    # return task id to the UI
    _log.info("Task: [#{task.id}] #{msg}")
    return_task_object ? task : task.id
  end

  def self.wait_for_taskid(task_id, options = {})
    options = options.dup
    options[:sleep_time] ||= 1
    options[:timeout] ||= 0
    task = MiqTask.find(task_id)
    return nil if task.nil?
    begin
      Timeout.timeout(options[:timeout]) do
        while task.state != STATE_FINISHED
          sleep(options[:sleep_time])
          # Code running with Rails QueryCache enabled,
          # need to disable caching for the reload to see updates.
          task.class.uncached { task.reload }
        end
      end
    rescue Timeout::Error
      update_status(task_id, STATE_FINISHED, STATUS_TIMEOUT, "Timed out stalled task.")
      task.reload
    end
    task
  end

  def self.delete_older(ts, condition)
    _log.info("Queuing deletion of tasks older than #{ts} and with condition: #{condition}")
    MiqQueue.submit_job(
      :class_name  => name,
      :method_name => "destroy_older_by_condition",
      :args        => [ts, condition],
    )
  end

  def self.destroy_older_by_condition(ts, condition)
    _log.info("Executing destroy_all for records older than #{ts} and with condition: #{condition}")
    MiqTask.where("updated_on < ?", ts).where(condition).destroy_all
  end

  def self.delete_by_id(ids)
    return if ids.empty?
    _log.info("Queuing deletion of tasks with the following ids: #{ids.inspect}")
    MiqQueue.submit_job(
      :class_name  => name,
      :method_name => "destroy",
      :args        => [ids],
    )
  end

  def self.human_status(state_or_status)
    HUMAN_STATUS[state_or_status] || STATUS_UNKNOWN
  end

  def process_cancel
    if job
      job.process_cancel
      _("The selected Task was cancelled")
    else
      _("This task can not be canceled")
      # TODO: implement 'cancel' operation for task
    end
  end

  def self.display_name(number = 1)
    n_('Task', 'Tasks', number)
  end

  private

  def initialize_attributes
    self.state ||= STATE_INITIALIZED
    self.status ||= STATUS_OK
    self.message ||= DEFAULT_MESSAGE
    self.userid ||= DEFAULT_USERID
  end
end
