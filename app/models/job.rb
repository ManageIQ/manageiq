class Job < ApplicationRecord
  include_concern 'StateMachine'
  include UuidMixin
  include FilterableMixin

  belongs_to :miq_task, :dependent => :delete

  serialize :options
  serialize :context
  alias_attribute :jobid, :guid

  before_destroy :check_active_on_destroy
  after_update_commit :update_linked_task

  DEFAULT_TIMEOUT = 300
  DEFAULT_USERID  = 'system'.freeze

  def self.get_job_class(process_type)
    return Object.const_get(process_type)
  rescue NameError
    raise "Cannot Find Job Class=<#{process_type}> because it is not defined"
  end

  def self.create_job(process_type, options = {})
    klass = get_job_class(process_type)
    ar_options = options.dup.delete_if { |k, _v| !Job.column_names.include?(k.to_s) }
    job = klass.new(ar_options)
    job.options = options
    job.initialize_attributes
    job.save
    job.create_miq_task(:status        => job.status.try(:capitalize),
                        :name          => job.name,
                        :message       => job.message,
                        :userid        => job.userid,
                        :state         => job.state.try(:capitalize),
                        :miq_server_id => job.miq_server_id,
                        :context_data  => job.context,
                        :zone          => job.zone)
    $log.info "Job created: guid: [#{job.guid}], userid: [#{job.userid}], name: [#{job.name}], target class: [#{job.target_class}], target id: [#{job.target_id}], process type: [#{job.type}], agent class: [#{job.agent_class}], agent id: [#{job.agent_id}], zone: [#{job.zone}]"
    job.signal(:initializing)
    job
  end

  def self.current_job_timeout(_timeout_adjustment = 1)
    DEFAULT_TIMEOUT
  end

  delegate :current_job_timeout, :to => :class

  def update_linked_task
    return if miq_task.nil?
    attributes = {}
    attributes[:context_data] = context if previous_changes['context']
    attributes[:started_on] = started_on if previous_changes['started_on']
    attributes[:zone] = zone if previous_changes['zone']
    attributes[:state] = state.try(:capitalize) if previous_changes['state']
    attributes[:status] = status.try(:capitalize) if previous_changes['status']
    attributes[:message] = message.truncate(255) if previous_changes['message']
    miq_task.update_attributes!(attributes)
  end

  def initialize_attributes
    self.name ||= "#{type} created on #{Time.now.utc}"
    self.userid ||= DEFAULT_USERID
    self.context ||= {}
    self.options ||= {}
    self.status   = "ok"
    self.code     = 0
    self.message  = "process initiated"
  end

  def check_active_on_destroy
    if self.is_active?
      _log.warn "Job is active, delete not allowed - guid: [#{guid}], userid: [#{self.userid}], name: [#{self.name}], target class: [#{target_class}], target id: [#{target_id}], process type: [#{type}], agent class: [#{agent_class}], agent id: [#{agent_id}], zone: [#{zone}]"
      throw :abort
    end

    _log.info "Job deleted: guid: [#{guid}], userid: [#{self.userid}], name: [#{self.name}], target class: [#{target_class}], target id: [#{target_id}], process type: [#{type}], agent class: [#{agent_class}], agent id: [#{agent_id}], zone: [#{zone}]"
    true
  end

  def self.agent_state_update_queue(jobid, state, message = nil)
    job = Job.where("guid = ?", jobid).select("id, state, guid").first
    unless job.nil?
      job.agent_state_update(state, message)
    else
      _log.warn "jobid: [#{jobid}] not found"
    end
  rescue => err
    _log.warn "Error '#{err.message}', updating jobid: [#{jobid}]"
    _log.log_backtrace(err)
  end

  def agent_state_update(agent_state, agent_message = nil)
    # Handle a single array parm coming from the queue
    agent_state, agent_message = agent_state if agent_state.kind_of?(Array)

    $log.info("JOB([#{guid}] Agent state update: state: [#{agent_state}], message: [#{agent_message}]")
    update_attributes(:agent_state => agent_state, :agent_message => agent_message)

    return unless self.is_active?

    # Update worker heartbeat
    MiqQueue.get_worker(guid).try(:update_heartbeat)
  end

  def self.signal_by_taskid(guid, signal, *args)
    # send a signal to job by guid
    return if guid.nil?

    _log.info("Guid: [#{guid}], Signal: [#{signal}]")

    job = find_by(:guid => guid)
    return if job.nil?

    begin
      job.signal(signal, *args)
    rescue => err
      _log.info("Guid: [#{guid}], Signal: [#{signal}], unable to deliver signal, #{err}")
    end
  end

  def set_status(message, status = "ok", code = 0)
    self.message = message
    self.status  = status
    self.code    = code

    save
  end

  def dispatch_start
    _log.info "Dispatch Status is 'pending'"
    self.dispatch_status = "pending"
    save
    @storage_dispatcher_process_finish_flag = false
  end

  def dispatch_finish
    return if @storage_dispatcher_process_finish_flag
    _log.info "Dispatch Status is 'finished'"
    self.dispatch_status = "finished"
    save
    @storage_dispatcher_process_finish_flag = true
  end

  def process_cancel(*args)
    options = args.first || {}
    options[:message] ||= options[:userid] ? "Job canceled by user [#{options[:useid]}] on #{Time.now}" : "Job canceled on #{Time.now}"
    options[:status] ||= "ok"
    _log.info "job canceling, #{options[:message]}"
    signal(:finish, options[:message], options[:status])
  end

  def process_error(*args)
    message, status = args
    _log.error message.to_s
    set_status(message, status, 1)
  end

  def process_abort(*args)
    message, status = args
    _log.error "job aborting, #{message}"
    set_status(message, status, 1)
    signal(:finish, message, status)
  end

  def process_finished(*args)
    message, status = args
    _log.info "job finished, #{message}"
    set_status(message, status)
    dispatch_finish
  end

  def timeout!
    MiqQueue.put_unless_exists(
      :class_name  => self.class.base_class.name,
      :instance_id => id,
      :method_name => "signal_abort",
      :role        => "smartstate",
      :zone        => MiqServer.my_zone
    ) do |_msg, find_options|
      message = "job timed out after #{Time.now - updated_on} seconds of inactivity.  Inactivity threshold [#{current_job_timeout} seconds]"
      _log.warn("Job: guid: [#{guid}], #{message}, aborting")
      find_options.merge(:args => [message, "error"])
    end
  end

  def target_entity
    target_class.constantize.find_by_id(target_id)
  end

  def self.check_jobs_for_timeout
    $log.debug "Checking for timed out jobs"
    begin
      in_my_region
        .where("state != 'finished' and (state != 'waiting_to_start' or dispatch_status = 'active')")
        .where("zone is null or zone = ?", MiqServer.my_zone)
        .each do |job|
          next unless job.updated_on < job.current_job_timeout(job.timeout_adjustment).seconds.ago

          # Allow jobs to run longer if the MiqQueue task is still active.  (Limited to MiqServer for now.)
          if job.agent_class == "MiqServer"
            # TODO: can we add method_name, queue_name, role, instance_id to the exists?
            next if MiqQueue.exists?(:state => %w(dequeue ready), :task_id => job.guid, :class_name => job.agent_class)
          end
          job.timeout!
        end
    rescue Exception
      _log.error($!.to_s)
    end
  end

  def timeout_adjustment
    timeout_adjustment = 1
    target = target_entity
    if target.kind_of?(ManageIQ::Providers::Microsoft::InfraManager::Vm) ||
       target.kind_of?(ManageIQ::Providers::Microsoft::InfraManager::Template)
      timeout_adjustment = 4
    end
    timeout_adjustment
  end

  def self.check_for_evm_snapshots(job_not_found_delay = 1.hour)
    Snapshot.remove_unused_evm_snapshots(job_not_found_delay)
  end

  def self.guid_active?(job_guid, timestamp, job_not_found_delay)
    job = Job.find_by(:guid => job_guid)

    # If job was found, return whether it is active
    return job.is_active? unless job.nil?

    # If Job is NOT found, consider active if timestamp is newer than (now - delay)
    if timestamp.kind_of?(String)
      timestamp = timestamp.to_time(:utc)
    else
      timestamp = timestamp.to_time rescue nil
    end
    return false if timestamp.nil?
    (timestamp >= job_not_found_delay.seconds.ago)
  end

  def self.extend_timeout(_host_id, jobs)
    jobs = Marshal.load(jobs)
    job_guids = jobs.collect { |j| j[:taskid] }
    unless job_guids.empty?
      Job.where(:guid => job_guids).where.not(:state => 'finished').each do |job|
        _log.debug("Job: guid: [#{job.guid}], job timeout extended due to work pending.")
        job.updated_on = Time.now.utc
        job.save
      end
    end
  end

  def is_active?
    !["finished", "waiting_to_start"].include?(state)
  end

  def self.delete_older(ts, condition)
    _log.info("Queuing deletion of jobs older than: #{ts}")
    ids = where("updated_on < ?", ts).where(condition).pluck("id")
    delete_by_id(ids)
  end

  def self.delete_by_id(ids)
    _log.info("Queuing deletion of jobs with the following ids: #{ids.inspect}")
    MiqQueue.put(
      :class_name  => name,
      :method_name => "destroy",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :args        => [ids],
      :zone        => MiqServer.my_zone
    )
  end
end # class Job
