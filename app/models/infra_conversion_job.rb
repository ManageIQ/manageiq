class InfraConversionJob < Job
  def self.create_job(options)
    # TODO: from settings/user plan settings
    options[:conversion_polling_interval] ||= Settings.transformation.limits.conversion_polling_interval # in seconds
    options[:poll_conversion_max] ||= Settings.transformation.limits.poll_conversion_max
    options[:poll_post_stage_max] ||= Settings.transformation.limits.poll_post_stage_max
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

    migration_task.preflight_check
    _log.info(prep_message("Preflight check passed, task.state=#{migration_task.state}. continue ..."))
    queue_signal(:poll_conversion)
  rescue => error
    message = prep_message("Preflight check has failed: #{error}")
    _log.info(message)
    abort_conversion(message, 'error')
  end

  def abort_conversion(message, status)
    migration_task.cancel
    queue_signal(:abort_job, message, status)
  end

  def polling_timeout(poll_type)
    count = "#{poll_type}_count".to_sym
    max = "#{poll_type}_max".to_sym
    context[count] = (context[count] || 0) + 1
    context[count] > options[max]
  end

  def poll_conversion
    return abort_conversion("Polling times out", 'error') if polling_timeout(:poll_conversion)

    message = "Getting conversion state"
    _log.info(prep_message(message))

    unless migration_task.options.fetch_path(:virtv2v_wrapper, 'state_file')
      message = "Virt v2v state file not available, continuing poll_conversion"
      _log.info(prep_message(message))
      update_attributes(:message => message)
      return queue_signal(:poll_conversion, :deliver_on => Time.now.utc + options[:conversion_polling_interval])
    end

    begin
      migration_task.get_conversion_state # migration_task.options will be updated
    rescue => exception
      _log.log_backtrace(exception)
      return abort_conversion("Conversion error: #{exception}", 'error')
    end

    v2v_status = migration_task.options[:virtv2v_status]
    message = "virtv2v_status=#{v2v_status}"
    _log.info(prep_message(message))
    update_attributes(:message => message)

    case v2v_status
    when 'active'
      queue_signal(:poll_conversion, :deliver_on => Time.now.utc + options[:conversion_polling_interval])
    when 'failed'
      message = "disk conversion failed"
      abort_conversion(prep_message(message), 'error')
    when 'succeeded'
      message = "disk conversion succeeded"
      _log.info(prep_message(message))
      queue_signal(:start_post_stage)
    else
      message = prep_message("Unknown converstion status: #{v2v_status}")
      abort_conversion(message, 'error')
    end
  end

  def start_post_stage
    # once we refactor Automate's PostTransformation into a job, we kick start it here
    message = "To wait for Post-Transformation progress"
    _log.info(prep_message(message))
    update_attributes(:message => message)
    queue_signal(:poll_post_stage, :deliver_on => Time.now.utc + options[:conversion_polling_interval])
  end

  def poll_post_stage
    return abort_conversion("Polling times out", 'error') if polling_timeout(:poll_post_stage)

    message = "PostTransformation state=#{migration_task.state}, status=#{migration_task.status}"
    _log.info(prep_message(message))
    update_attributes(:message => message)
    if migration_task.state == 'finished'
      self.status = migration_task.status
      queue_signal(:finish)
    else
      queue_signal(:poll_post_stage, :deliver_on => Time.now.utc + options[:conversion_polling_interval])
    end
  end

  def queue_signal(*args, deliver_on: nil)
    MiqQueue.put(
      :class_name  => self.class.name,
      :method_name => "signal",
      :instance_id => id,
      :role        => "ems_operations",
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
