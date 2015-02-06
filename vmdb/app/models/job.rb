class Job < ActiveRecord::Base
  include_concern 'StateMachine'
  include UuidMixin
  include ReportableMixin
  include FilterableMixin

  serialize :options
  serialize :context
  alias_attribute :jobid, :guid

  before_destroy :check_active_on_destroy

  DEFAULT_TIMEOUT = 300
  DEFAULT_USERID  = 'system'.freeze

  def self.get_job_class(process_type)
    begin
      return Object.const_get(process_type)
    rescue NameError
      raise "Cannot Find Job Class=<#{process_type}> because it is not defined"
    end
  end

  def self.create_job(process_type, options = {})
    klass = self.get_job_class(process_type)
    ar_options = options.dup.delete_if { |k,v| !Job.column_names.include?(k.to_s) }
    job = klass.new(ar_options)
    job.options = options
    job.initialize_attributes
    job.save
    $log.info "Job created: guid: [#{job.guid}], userid: [#{job.userid}], name: [#{job.name}], target class: [#{job.target_class}], target id: [#{job.target_id}], process type: [#{job.type}], agent class: [#{job.agent_class}], agent id: [#{job.agent_id}], zone: [#{job.zone}]"
    job.signal(:initializing)
    job
  end

  def initialize_attributes
    self.name    ||= "#{self.type} created on #{Time.now.utc}"
    self.userid  ||= DEFAULT_USERID
    self.context ||= {}
    self.options ||= {}
    self.status   = "ok"
    self.code     = 0
    self.message  = "process initiated"
  end

  def check_active_on_destroy
    if self.is_active?
      $log.warn "MIQ(Job.destroy) Job is active, delete not allowed - guid: [#{self.guid}], userid: [#{self.userid}], name: [#{self.name}], target class: [#{self.target_class}], target id: [#{self.target_id}], process type: [#{self.type}], agent class: [#{self.agent_class}], agent id: [#{self.agent_id}], zone: [#{self.zone}]"
      return false
    end

    $log.info "MIQ(Job.destroy) Job deleted: guid: [#{self.guid}], userid: [#{self.userid}], name: [#{self.name}], target class: [#{self.target_class}], target id: [#{self.target_id}], process type: [#{self.type}], agent class: [#{self.agent_class}], agent id: [#{self.agent_id}], zone: [#{self.zone}]"
    return true
  end

  def self.agent_state_update_queue(jobid, state, message=nil)
    begin
      job = Job.where("guid = ?", jobid).select("id, state, guid").first
      unless job.nil?
        job.agent_state_update(state, message)
      else
        $log.warn "MIQ(Job.agent_job_state): jobid: [#{jobid}] not found"
      end
    rescue => err
      $log.warn "MIQ(Job.agent_job_state): Error '#{err.message}', updating jobid: [#{jobid}]"
      $log.log_backtrace(err)
    end
  end

  def agent_state_update(agent_state, agent_message=nil)
    # Handle a single array parm coming from the queue
    agent_state, agent_message = agent_state if agent_state.kind_of?(Array)

    $log.info("JOB([#{self.guid}] Agent state update: state: [#{agent_state}], message: [#{agent_message}]")
    self.update_attributes(:agent_state => agent_state, :agent_message => agent_message)

    return unless self.is_active?

    # Update worker heartbeat
    worker = MiqQueue.get_worker(self.guid)
    worker.update_heartbeat unless worker.nil?
  end

  def self.signal_by_taskid(guid, signal, *args)
    # send a signal to job by guid
    return if guid.nil?

    $log.info("MIQ(job-signal_by_taskid) Guid: [#{guid}], Signal: [#{signal}]")

    job = self.find_by_guid(guid)
    return if job.nil?

    begin
      job.signal(signal, *args)
    rescue => err
      $log.info("MIQ(job-signal_by_taskid) Guid: [#{guid}], Signal: [#{signal}], unable to deliver signal, #{err}")
    end
  end

  def set_status(message, status="ok", code = 0)
    self.message = message
    self.status  = status
    self.code    = code

    self.save
  end

  def dispatch_start
    $log.info "dispatch_start: Dispatch Status is 'pending'"
    self.dispatch_status = "pending"
    self.save
    @storage_dispatcher_process_finish_flag = false
  end

  def dispatch_finish
    return if @storage_dispatcher_process_finish_flag
    $log.info "dispatch_finish: Dispatch Status is 'finished'"
    self.dispatch_status = "finished"
    self.save
    @storage_dispatcher_process_finish_flag = true
  end

  def process_cancel(*args)
    options = args.first || {}
    options[:message] ||= options[:userid] ? "Job canceled by user [#{options[:useid]}] on #{Time.now}" : "Job canceled on #{Time.now}"
    options[:status] ||= "ok"
    $log.info "action-cancel: job canceling, #{options[:message]}"
    signal(:finish, options[:message], options[:status])
  end

  def process_error(*args)
    message, status = args
    $log.error "action-error: #{message}"
    set_status(message, status, 1)
  end

  def process_abort(*args)
    message, status = args
    $log.error "action-abort: job aborting, #{message}"
    set_status(message, status, 1)
    signal(:finish, message, status)
  end

  def process_finished(*args)
    message, status = args
    $log.info "action-finished: job finished, #{message}"
    set_status(message, status)
    dispatch_finish
  end

  def timeout!
    MiqQueue.put_unless_exists(
      :class_name    => self.class.base_class.name,
      :instance_id   => id,
      :method_name   => "signal",
      :args_selector => lambda {|args| args.kind_of?(Array) && args.first == :abort},
      :role          => "smartstate",
      :zone          => MiqServer.my_zone
    ) do |msg, find_options|
      message = "job timed out after #{Time.now - updated_on} seconds of inactivity.  Inactivity threshold [#{DEFAULT_TIMEOUT} seconds]"
      $log.warn("MIQ(job-check_jobs_for_timeout) Job: guid: [#{guid}], #{message}, aborting")
      find_options.merge(:args => [:abort, message, "error"])
    end
  end

  def self.check_jobs_for_timeout
    $log.debug "Checking for timed out jobs"
    begin
      self.in_my_region.find(:all, :conditions => ["((state != 'finished' and state != 'waiting_to_start') or (state = 'waiting_to_start' and dispatch_status = 'active')) and (zone is null or zone = ?)", MiqServer.my_zone]).each do |job|
        if job.updated_on < DEFAULT_TIMEOUT.seconds.ago
          # Allow jobs to run longer if the MiqQueue task is still active.  (Limited to MiqServer for now.)
          if job.agent_class == "MiqServer"
            # TODO: can we add method_name, queue_name, role, instance_id to the exists?
            next if MiqQueue.exists?(:state => ["dequeue", "ready"], :task_id => job.guid, :class_name => job.agent_class.to_s)
          end
          job.timeout!
        end
      end
    rescue Exception
      $log.error("MIQ(job-check_jobs_for_timeout) #{$!}")
    end
  end

  def self.check_for_evm_snapshots(job_not_found_delay = 1.hour)
    Snapshot.remove_unused_evm_snapshots(job_not_found_delay)
  end

  def self.guid_active?(job_guid, timestamp, job_not_found_delay)
    job = Job.find_by_guid(job_guid)

    # If job was found, return whether it is active
    return job.is_active? unless job.nil?

    # If Job is NOT found, consider active if timestamp is newer than (now - delay)
    timestamp = timestamp.to_time rescue nil
    return false if timestamp.nil?
    return (timestamp >= job_not_found_delay.seconds.ago)
  end

  def self.extend_timeout(host_id, jobs)
    jobs = Marshal.load(jobs)
    job_guids = jobs.collect { |j| j[:taskid] }
    unless job_guids.empty?
      Job.find(:all, :conditions => ["state != 'finished' and guid in (?)", job_guids]).each do |job|
        $log.debug("MIQ(job-extend_timeout) Job: guid: [#{job.guid}], job timeout extended due to work pending.")
        job.updated_on = Time.now.utc
        job.save
      end
    end
  end

  def is_active?
    !["finished", "waiting_to_start"].include?(self.state)
  end

  def self.delete_older(ts, condition)
    $log.info("MIQ(job-delete_older) Queuing deletion of jobs older than: #{ts}")
    cond = condition.blank? ? [] : [[condition].flatten.first, [condition].flatten[1..-1]]
    cond[0] ||= []
    cond[1] ||= []

    ts_clause = "updated_on < ?"
    cond[0].empty? ? cond[0] << ts_clause : cond[0] = "(#{cond[0]}) AND #{ts_clause}"
    cond[1] << ts.utc

    $log.info("MIQ(job-delete_older) cond.flatten: #{cond.flatten.inspect}")
    ids = self.where(cond.flatten).pluck(:id)

    self.delete_by_id(ids)
  end

  def self.delete_by_id(ids)
    ids = [ids].flatten
    $log.info("MIQ(job-delete_by_id) Queuing deletion of jobs with the following ids: #{ids.inspect}")
    MiqQueue.put(
      :class_name  => self.name,
      :method_name => "destroy",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :args        => [ids],
      :zone        => MiqServer.my_zone
    )
  end
end # class Job
