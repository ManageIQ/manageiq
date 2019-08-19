class InfraConversionJob < Job
  def self.create_job(options)
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
      :initializing                => {'initialize'       => 'waiting_to_start'},
      :start                       => {'waiting_to_start' => 'started'},
      :poll_automate_state_machine => {
        'started'             => 'running_in_automate',
        'running_in_automate' => 'running_in_automate'
      },
      :finish                      => {'*'                => 'finished'},
      :abort_job                   => {'*'                => 'aborting'},
      :cancel                      => {'*'                => 'canceling'},
      :error                       => {'*'                => '*'}
    }
  end

  def load_states
    {
      :running_in_automate => {
        :max_retries => 8640 # 36 hours with a retry interval of 15 seconds
      }
    }
  end

  def states
    @states ||= load_states
  end

  def migration_task
    @migration_task ||= target_entity
    # valid states: %w(migrated pending finished active queued)
  end

  # Temporary method to allow switching from InfraConversionJob to Automate.
  # In Automate, another method waits for workflow_runner to be 'automate'.
  def handover_to_automate
    migration_task.update_options(:workflow_runner => 'automate')
  end

  def abort_conversion(message, status)
    migration_task.cancel
    queue_signal(:abort_job, message, status)
  end

  def polling_timeout
    options[:retry_interval] ||= Settings.transformation.job.retry_interval # in seconds
    return false if states[state.to_sym][:max_retries].nil?
    retries = "retries_#{state}".to_sym
    context[retries] = (context[retries] || 0) + 1
    context[retries] > states[state.to_sym][:max_retries]
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

  # --- Methods that implement the state machine transitions --- #

  def start
    migration_task.update!(:state => 'migrate')
    handover_to_automate
    queue_signal(:poll_automate_state_machine)
  end

  def poll_automate_state_machine
    return abort_conversion('Polling timed out', 'error') if polling_timeout

    message = "Migration Task vm=#{migration_task.source.name}, state=#{migration_task.state}, status=#{migration_task.status}"
    _log.info(prep_message(message))
    update_attributes(:message => message)
    if migration_task.state == 'finished'
      self.status = migration_task.status
      queue_signal(:finish)
    else
      queue_signal(:poll_automate_state_machine, :deliver_on => Time.now.utc + options[:retry_interval])
    end
  end
end
