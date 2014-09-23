class MiqTask < ActiveRecord::Base
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
  validates_inclusion_of :state,  :in => [STATE_INITIALIZED, STATE_QUEUED, STATE_ACTIVE, STATE_FINISHED]
  validates_inclusion_of :status, :in => [STATUS_OK, STATUS_WARNING, STATUS_ERROR, STATUS_TIMEOUT]

  DEFAULT_MESSAGE   = 'Initialized'.freeze
  DEFAULT_USERID    = 'system'.freeze

  MESSAGE_TASK_COMPLETED_SUCCESSFULLY   = 'Task completed successfully'
  MESSAGE_TASK_COMPLETED_UNSUCCESSFULLY = 'Task did not complete successfully'

  has_one :log_file, :dependent => :destroy
  has_one :binary_blob, :as => :resource, :dependent => :destroy
  has_one :miq_report_result, :dependent => :destroy

  before_validation :initialize_attributes, :on => :create

  include ReportableMixin

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
    task = MiqTask.find_by_id(taskid)
    task.update_status(state, status, message) unless task.nil?
  end

  def update_status(state, status, message)
    status = STATUS_ERROR if status == STATUS_EXPIRED
    $log.info("MIQ(MiqTask.update_status) Task: [#{self.id}] [#{state}] [#{status}] [#{message}]")
    self.update_attributes!(:state => state, :status => status, :message => self.class.trim_message(message))
  end

  def self.update_message(taskid, message)
    task = MiqTask.find_by_id(taskid)
    task.update_message(message) unless task.nil?
  end

  def update_message(message)
    $log.info("MIQ(MiqTask.update_message) Task: [#{self.id}] [#{message}]")
    self.update_attributes!(:message => self.class.trim_message(message))
  end

  def update_context(context)
    self.update_attributes!(:context_data => context)
  end

  def self.trim_message(message)
    # Trim the message to the first 255 bytes
    msg = message.dup.to_s
    msg = msg[0..251] + "..." if msg.length > 255
    msg
  end

  def message=(message)
    super(self.class.trim_message(message))
  end

  def self.info(taskid, message, pct_complete)
    task = MiqTask.find_by_id(taskid)
    task.info(message, pct_complete) unless task.nil?
  end

  def info(message, pct_complete)
    self.update_attributes(:message => message, :pct_complete => pct_complete, :status => STATUS_OK)
  end

  def warn(message)
    self.update_attributes(:message => message, :status => STATUS_WARNING)
  end

  def self.warn(taskid, message)
    task = MiqTask.find_by_id(taskid)
    task.warn(message) unless task.nil?
  end

  def error(message)
    self.update_attributes(:message => message, :status => STATUS_ERROR)
  end

  def self.error(taskid, message)
    task = MiqTask.find_by_id(taskid)
    task.error(message) unless task.nil?
  end

  def self.state_initialized(taskid)
    task = MiqTask.find_by_id(taskid)
    task.state_initialized unless task.nil?
  end

  def state_initialized
    self.update_attributes(:state => STATE_INITIALIZED)
  end

  def self.state_queued(taskid)
    task = MiqTask.find_by_id(taskid)
    task.state_queued unless task.nil?
  end

  def state_queued
    self.update_attributes(:state => STATE_QUEUED)
  end

  def self.state_active(taskid)
    task = MiqTask.find_by_id(taskid)
    task.state_active unless task.nil?
  end

  def state_active
    self.update_attributes(:state => STATE_ACTIVE)
  end

  def self.state_finished(taskid)
    task = MiqTask.find_by_id(taskid)
    task.state_finished unless task.nil?
  end

  def state_finished
    self.update_attributes(:state => STATE_FINISHED)
  end

  def queue_callback(state, status, message, result)
    if status.casecmp(STATUS_OK) == 0
      message = MESSAGE_TASK_COMPLETED_SUCCESSFULLY
    else
      message = MESSAGE_TASK_COMPLETED_UNSUCCESSFULLY if message.blank?
    end

    self.task_results = result unless result.nil?
    self.update_status(state, status.titleize, message)
  end

  def queue_callback_on_exceptions(state, status, message, result)
    # Only callback if status is not "ok"
    unless status.casecmp(STATUS_OK) == 0
      self.task_results = result unless result.nil?
      self.update_status(state, STATUS_ERROR, message)
    end
  end

  def task_results
    # support legacy task that saved results in the results column
    return Marshal.load(Base64.decode64(self.results.split("\n").join)) unless self.results.nil?
    return self.miq_report_result.report_results unless self.miq_report_result.nil?
    unless self.binary_blob.nil?
      serializer_name = self.binary_blob.data_type
      serializer_name = "Marshal" unless serializer_name == "YAML"  # YAML or Marshal, for now
      serializer = serializer_name.constantize
      return serializer.load(self.binary_blob.binary)
    end
    return nil
  end

  def task_results=(value)
    self.binary_blob        = BinaryBlob.new(:name => "task_results", :data_type => "YAML")
    self.binary_blob.binary = YAML.dump(value)
  end

  def log_data
    self.log_file.nil? ? nil : self.log_file.file_from_db
  end

  def cleanup_log
    self.log_file.destroy unless self.log_file.nil?
  end

  def self.generic_action_with_callback(options, queue_options)
    # Pre-reqs:
    # options hash contains the following required keys:
    #   :action => the human friendly name of the action to be run
    #   :userid => the user this is being run for... aka, the logged on user who invoked the action in the UI
    #
    # queue options is a hash containing the following required keys:
    #   :class_name
    #   :method_name
    #   :args
    # queue_options keys that are not required but may be needed:
    #   :instance_id (if using an instance method...an id)
    #   :queue_name (which queue, priority?)
    #   :zone (zone of the request)
    #   :guid (guid of the server to run the action)
    #   :role (role of the server to run the action)
    #   :msg_timeout => how long you want to wait before pulling the plug on the action (seconds)

    log_prefix = 'MIQ(MiqTask.generic_action_with_callback)'
    task = MiqTask.create(:name => options[:action], :userid => options[:userid])

    # Set the callback for this task to set the status based on the results of the actions
    queue_options[:miq_callback] = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback, :args => ['Finished']}
    method_opts = queue_options[:args].first
    method_opts[:task_id] = task.id if method_opts.kind_of?(Hash)
    MiqQueue.put(queue_options)

    # return task id to the UI
    msg =  "Queued the action: [#{options[:action]}] being run for user: [#{options[:userid]}]"
    task.update_status(STATE_QUEUED, STATUS_OK, msg)
    $log.info("#{log_prefix} Task: [#{task.id}] #{msg}")
    task.id
  end

  def self.wait_for_taskid(task_id, options = {})
    options = options.dup
    options[:sleep_time] ||= 1
    options[:timeout]    ||= 0
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
    log_prefix = 'MIQ(MiqTask.delete_older)'
    $log.info("#{log_prefix} Queuing deletion of tasks older than: #{ts}")
    cond = condition.blank? ? [] : [[condition].flatten.first, [condition].flatten[1..-1]]
    cond[0] ||= []
    cond[1] ||= []

    ts_clause = "updated_on < ?"
    cond[0].empty? ? cond[0] << ts_clause : cond[0] = "(#{cond[0]}) AND #{ts_clause}"
    cond[1] << ts.utc

    $log.info("#{log_prefix} cond.flatten: #{cond.flatten.inspect}")
    ids = self.find(:all, :conditions => cond.flatten, :select => "id").collect {|j| j.id}

    self.delete_by_id(ids)
  end

  def self.delete_by_id(ids)
    ids = [ids].flatten
    $log.info("MIQ(MiqTask.delete_by_id) Queuing deletion of tasks with the following ids: #{ids.inspect}")
    MiqQueue.put(
      :class_name  => self.name,
      :method_name => "destroy_all",
      :args        => [["id in (?)", ids]],
      :zone        => MiqServer.my_zone
    )
  end

  private

  def initialize_attributes
    self.state   ||= STATE_INITIALIZED
    self.status  ||= STATUS_OK
    self.message ||= DEFAULT_MESSAGE
    self.userid  ||= DEFAULT_USERID
  end
end
