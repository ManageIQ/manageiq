class ManageIQ::Providers::InfraMigrationJob < Job
  POLL_CONVERSION_INTERVAL = 60

  def self.create_job(options)
    # TODO: expect options[:target_class] and options[:target_id]
    options[:conversion_polling_interval] = POLL_CONVERSION_INTERVAL # TODO: from settings
    super(name, options)
  end

  #
  # State-transition diagram:
  #                              :poll_native_task
  #    *                          /-------------\
  #    | :initialize              |             |
  #    v               :start     v             |
  # waiting_to_start --------> running ------------------------------> refreshing <---------\
  #                               |                     :refresh           |                |
  #                               |                                        |                |
  #                               |                                        |----------------/
  #                               v                                        |   :poll_refresh
  #                             error <------------------------------------|
  #                                                     :error             |
  #                                                                        |
  #       finished <---------- post_refreshing <---------------------------/
  #                   :finish                           :post_refresh
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
      :start            => {'waiting_to_start' => 'pre_conversion'},
      :pre_conversion   => {'pre_conversion'   => 'pre_conversion'},
      :run_conversion   => {'pre_conversion'   => 'running'},
      :poll_conversion  => {'running'          => 'running'},
      :refresh          => {'running'          => 'refreshing'},
      :finish           => {'*'                => 'finished'},
      :abort_job        => {'*'                => 'aborting'},
      :cancel           => {'*'                => 'canceling'},
      :error            => {'*'                => '*'}
    }
  end

  def migration_task
    @migration_task ||= target_entity
  end

  def start
    # TransformationCleanup 3 things:
    #  - kill v2v
    #  - power_on: ignored
    #  - check_power_on: ignore
    migration_task.kill_virtv2v('KILL') # TODO: KILL or TERM

    if migration_task.preflight_check
      _log.info(prep_message("Preflight check passed, continue"))
      queue_signal(:pre_conversion)
    else
      message = prep_message("Preflight check has failed")
      _log.info(message)
      queue_signal(:abort_job, message, 'error')
    end
  end

  def pre_conversion
    _log.info(prep_message(""))
    status = migration_task.options # waiting on automate's pre_transformation
    case status
    when ''
      queue_signal(:pre_conversion, :deliver_on => Time.now.utc + options[:conversion_polling_interval])
    when 'done'
      _log.info(prep_message("PreTransformation in automate finished"))
      queue_signal(:run_conversion)
    else
      message = prep_message("Unknown PreTransformation status: #{status}")
      queue_signal(:abort_job, message, 'error')
    end
  end

  def run_conversion
    _log.info(prep_message("Starting conversion..."))
    begin
      migration_task.run_conversion
      _log.info(prep_message("Conversion started. Start polling: virtv2v_wrapper=#{migration_task.options[:virtv2v_wrapper]}"))
      queue_signal(:poll_conversion, :deliver_on => Time.now.utc + options[:conversion_polling_interval])
    rescue => exception
      message = prep_message("Failed to start conversion: #{exception}")
      _log.error(message)
      return queue_signal(:abort_job, message, 'error')
    end
  end

  def poll_conversion
    _log.info(prep_message("Getting conversion state"))
    begin
      migration_task.get_conversion_state # task.options will be updated
    rescue => exception
      _log.log_backtrace(exception)
      return queue_signal(:abort_job, "Conversion error: #{exception}", 'error')
    end

    status = migration_task.options[:virtv2v_status]
    _log.info(prep_message("virtv2v_status=#{status}"))
    update_attributes(:updated_on => Time.now.utc) # update self.updated_on to prevent timing out
    case status
    when 'active'
      queue_signal(:poll_conversion, :deliver_on => Time.now.utc + options[:conversion_polling_interval])
    when 'failed'
      message = prep_message("conversion failed")
      _log.error(message)
      queue_signal(:abort_job, message, 'error')
    when 'succeeded'
      _log.info(prep_message("conversion succeeded"))
      queue_signal(:finish)
    else
      message = prep_message("Unknown converstion status: #{status}")
      queue_signal(:abort_job, message, 'error')
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
    "MiqRequestTask id=#{migration_task.id}, InfraMigrationJob id=#{id}. #{contents}"
  end
end
