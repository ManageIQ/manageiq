class Job < ApplicationRecord
  include StateMachineMixin
  include UuidMixin
  include FilterableMixin

  belongs_to :miq_task, :dependent => :delete
  belongs_to :miq_server

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
    job.create_miq_task(job.attributes_for_task)
    $log.info("Job created: #{job.attributes_log}")
    job.signal(:initializing)
    job
  end

  def self.current_job_timeout(_timeout_adjustment = 1)
    DEFAULT_TIMEOUT
  end

  delegate :current_job_timeout, :to => :class

  def update_linked_task
    miq_task.update_attributes!(attributes_for_task) unless miq_task.nil?
  end

  def initialize_attributes
    self.name ||= "#{type} created on #{Time.now.utc}"
    self.userid ||= DEFAULT_USERID
    self.context ||= {}
    self.options ||= {}
    self.status   = "ok"
    self.message  = "process initiated"
  end

  def check_active_on_destroy
    if self.is_active?
      _log.warn("Job is active, delete not allowed - #{attributes_log}")
      throw :abort
    end

    _log.info("Job deleted: #{attributes_log}")
    true
  end

  def self.update_message(job_guid, message)
    job = Job.find_by(:guid => job_guid)
    if job
      job.update_message(message)
    else
      _log.warn("jobs.guid: [#{jobid}] not found")
    end
  end

  def update_message(message)
    $log.info("JOB([#{guid}] Message update: [#{message}]")
    self.message = message
    save

    return unless self.is_active?

    # Update worker heartbeat
    MiqQueue.get_worker(guid).try(:update_heartbeat)
  end

  def set_status(message, status = "ok")
    self.message = message
    self.status  = status

    save
  end

  def dispatch_start
    _log.info("Dispatch Status is 'pending'")
    self.dispatch_status = "pending"
    save
    @storage_dispatcher_process_finish_flag = false
  end

  def dispatch_finish
    return if @storage_dispatcher_process_finish_flag
    _log.info("Dispatch Status is 'finished'")
    self.dispatch_status = "finished"
    save
    @storage_dispatcher_process_finish_flag = true
  end

  def process_cancel(*args)
    options = args.first || {}
    options[:message] ||= options[:userid] ? "Job canceled by user [#{options[:useid]}] on #{Time.now}" : "Job canceled on #{Time.now}"
    options[:status] ||= "ok"
    _log.info("job canceling, #{options[:message]}")
    signal(:finish, options[:message], options[:status])
  end

  def process_error(*args)
    message, status = args
    _log.error(message.to_s)
    set_status(message, status)
  end

  def process_abort(*args)
    message, status = args
    _log.error("job aborting, #{message}")
    set_status(message, status)
    signal(:finish, message, status)
  end

  def process_finished(*args)
    message, status = args
    _log.info("job finished, #{message}")
    set_status(message, status)
    dispatch_finish
  end

  def timeout!
    message = "job timed out after #{Time.now - updated_on} seconds of inactivity.  Inactivity threshold [#{current_job_timeout} seconds]"
    _log.warn("Job: guid: [#{guid}], #{message}, aborting")
    attributes = { :args => [message, "error"] }
    MiqQueue.create_with(attributes).put_unless_exists(
      :class_name  => self.class.base_class.name,
      :instance_id => id,
      :method_name => "signal_abort",
      :role        => "smartstate",
      :zone        => MiqServer.my_zone
    )
  end

  def target_entity
    target_class.constantize.find_by(:id => target_id) if target_class
  end

  def self.check_jobs_for_timeout
    $log.debug("Checking for timed out jobs")
    begin
      in_my_region
        .where("state != 'finished' and (state != 'waiting_to_start' or dispatch_status = 'active')")
        .where("zone is null or zone = ?", MiqServer.my_zone)
        .each do |job|
          next unless job.updated_on < job.current_job_timeout(job.timeout_adjustment).seconds.ago

          # Allow jobs to run longer if the MiqQueue task is still active.  (Limited to MiqServer for now.)
          # TODO: can we add method_name, queue_name, role, instance_id to the exists?
          if job.miq_server_id
            next if MiqQueue.exists?(:state => %w(dequeue ready), :task_id => job.guid, :class_name => "MiqServer")
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
    elsif target.kind_of?(ManageIQ::Providers::Azure::CloudManager::Vm) ||
          target.kind_of?(ManageIQ::Providers::Azure::CloudManager::Template)
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
    MiqQueue.submit_job(
      :class_name  => name,
      :method_name => "destroy",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :args        => [ids],
    )
  end

  def attributes_for_task
    {:status        => status.try(:capitalize),
     :state         => state == "waiting_to_start" ? MiqTask::STATE_QUEUED : state.try(:capitalize),
     :name          => name,
     :message       => message,
     :userid        => userid,
     :miq_server_id => miq_server_id,
     :context_data  => context,
     :zone          => zone,
     :started_on    => started_on}
  end

  def attributes_log
    "guid: [#{guid}], userid: [#{self.userid}], name: [#{self.name}], target class: [#{target_class}], target id: [#{target_id}], process type: [#{type}], server id: [#{miq_server_id}], zone: [#{zone}]"
  end
end # class Job
