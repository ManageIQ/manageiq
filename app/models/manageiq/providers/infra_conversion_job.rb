class ManageIQ::Providers::InfraConversionJob < Job
  POLL_CONVERSION_INTERVAL = 60

  def self.create_job(options)
    # expect options[:target_class] and options[:target_id]
    options[:conversion_polling_interval] = POLL_CONVERSION_INTERVAL # TODO: from settings
    super(name, options)
  end

  #
  # State-transition diagram:
  #                              :poll_conversion                         :poll_post_stage
  #    *                          /-------------\                        /---------------\
  #    | :initialize              |             |                        |               |
  #    v               :start     v             |                        v               |
  # waiting_to_start --------> running ------------------------------> post_conversion --/
  #     |                         |                :start_post_stage       |
  #     | :abort_job              | :abort_job                             |
  #     \------------------------>|                                        | :finish
  #                               v                                        |
  #                             aborting --------------------------------->|
  #                                                    :finish             v
  #                                                                    finished
  #

  alias_method :initializing, :dispatch_start
  alias_method :finish,       :process_finished
  alias_method :abort_job,    :process_abort
  alias_method :cancel,       :process_cancel
  alias_method :error,        :process_error

  def load_transitions
    self.state ||= 'initialize'

    {
      :initializing     => {'initialize'       => 'waiting_to_start'},
      :start            => {'waiting_to_start' => 'running'},
      :poll_conversion  => {'running'          => 'running'},
      :start_post_stage => {'running'          => 'post_conversion'},
      :poll_post_stage  => {'post_conversion'  => 'post_conversion'},
      :finish           => {'*'                => 'finished'},
      :abort_job        => {'*'                => 'aborting'},
      :cancel           => {'*'                => 'canceling'},
      :error            => {'*'                => '*'}
    }
  end

  def migration_task
    @migration_task ||= target_entity
    # valid states: %w(migrated pending finished active queued)
  end

  def start
    # TransformationCleanup 3 things:
    #  - kill v2v: ignored because no converion_host is there yet in the original automate-based logic
    #  - power_on: ignored
    #  - check_power_on: ignore

    if migration_task.preflight_check
      _log.info(prep_message("Preflight check passed, continue"))
      migration_task.set_ready
      _log.info(prep_message("task.state=#{migration_task.state}"))
      queue_signal(:poll_conversion)
    else
      message = prep_message("Preflight check has failed")
      _log.info(message)
      abort_conversion(message, 'error')
    end
  end

  def abort_conversion(message, status)
    migration_task.cancel
    queue_signal(:abort_job, message, status)
  end

  def poll_conversion
    # TODO: how much time should we wait before timing out?
    self.message = "Getting conversion state"
    _log.info(prep_message(message))

    if migration_task.options[:virtv2v_wrapper].nil? || migration_task.options[:virtv2v_wrapper]['state_file'].nil?
      self.message = "options[:virtv2v_wrapper]['state_file'] not available, continuing poll_conversion"
      _log.info(prep_message(message))
      return queue_signal(:poll_conversion, :deliver_on => Time.now.utc + options[:conversion_polling_interval])
    end

    begin
      migration_task.get_conversion_state # task.options will be updated
    rescue => exception
      _log.log_backtrace(exception)
      return abort_conversion("Conversion error: #{exception}", 'error')
    end

    v2v_status = migration_task.options[:virtv2v_status]
    self.message = "virtv2v_status=#{status}"
    _log.info(prep_message(message))

    case v2v_status
    when 'active'
      queue_signal(:poll_conversion, :deliver_on => Time.now.utc + options[:conversion_polling_interval])
    when 'failed'
      self.message = "disk conversion failed"
      abort_conversion(prep_message(message), 'error')
    when 'succeeded'
      self.message = "disk conversion succeeded"
      _log.info(prep_message(message))
      queue_signal(:start_post_stage)
    else
      self.message = prep_message("Unknown converstion status: #{v2v_status}")
      abort_conversion(message, 'error')
    end
  end

  def start_post_stage
    # once we refactor Automate's PostTransformation into a job, we kick start it here
    self.message = 'To wait for PostTransformation ...'
    _log.info(prep_message("To start polling for PostTransformation stage"))
    queue_signal(:poll_post_stage, :deliver_on => Time.now.utc + options[:conversion_polling_interval])
  end

  def poll_post_stage
    self.message = "PostTransformation state=#{migration_task.state}, status=#{migration_task.status}"
    _log.info(prep_message(message))
    if migration_task.state == 'finished'
      self.status = migration_task.status
      queue_signal(:finish)
    else
      queue_signal(:poll_post_stage, :deliver_on => Time.now.utc + options[:conversion_polling_interval])
    end
  end

  def queue_signal(*args, deliver_on: nil)
    role     = options[:role] || "ems_operations"
    priority = options[:priority] || MiqQueue::NORMAL_PRIORITY

    MiqQueue.put(
      :class_name  => self.class.name,
      :method_name => "signal",
      :instance_id => id,
      :priority    => priority,
      :role        => role,
      :zone        => zone,
      :task_id     => guid,
      :args        => args,
      :deliver_on  => deliver_on
    )
  end

  def prep_message(contents)
    "MiqRequestTask id=#{migration_task.id}, InfraConversionJob id=#{id}. #{contents}"
  end
end
