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
  # TODO: Update this diagram after we've settled on the updated state transitions.

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
      :collapse_snapshots          => {
        'started'              => 'collapsing_snapshots',
        'collapsing_snapshots' => 'collapsing_snapshots'
      },
      :poll_automate_state_machine => {
        'collapsing_snapshots' => 'running_in_automate',
        'running_in_automate'  => 'running_in_automate'
      },
      :finish                      => {'*'                => 'finished'},
      :abort_job                   => {'*'                => 'aborting'},
      :cancel                      => {'*'                => 'canceling'},
      :error                       => {'*'                => '*'}
    }
  end

  # Example state:
  #   :state_name => {
  #     :description => 'State description',
  #     :weight      => 30,
  #     :max_retries => 960
  #   }
  def state_settings
    @state_settings ||= {
      :collapsing_snapshots => {
        :description => 'Collapse snapshosts',
        :weight      => 5,
        :max_retries => 4.hours / state_retry_interval
      },
      :running_in_automate => {
        :max_retries => 36.hours / state_retry_interval
      }
    }
  end

  def state_retry_interval
    @state_retry_interval ||= Settings.transformation.job.retry_interval || 15.seconds
  end

  def migration_task
    @migration_task ||= target_entity
    # valid states: %w(migrate pending finished active queued)
  end

  def on_entry(state_hash, _)
    state_hash || {
      :state       => 'active',
      :status      => 'Ok',
      :description => state_settings[state.to_sym][:description],
      :started_on  => Time.now.utc,
      :percent     => 0.0
    }.compact
  end

  def on_retry(state_hash, state_progress = nil)
    if state_progress.nil?
      state_hash[:percent] = context["retries_#{state}".to_sym].to_f / state_settings[state.to_sym][:max_retries].to_f * 100.0
    else
      state_hash.merge!(state_progress)
    end
    state_hash[:updated_on] = Time.now.utc
    state_hash
  end

  def on_exit(state_hash, _)
    state_hash[:state] = 'finished'
    state_hash[:percent] = 100.0
    state_hash[:updated_on] = Time.now.utc
    state_hash
  end

  def on_error(state_hash, _)
    state_hash[:state] = 'finished'
    state_hash[:status] = 'Error'
    state_hash[:updated_on] = Time.now.utc
    state_hash
  end

  def update_migration_task_progress(state_phase, state_progress = nil)
    progress = migration_task.options[:progress] || { :current_state => state, :percent => 0.0, :states => {} }
    state_hash = send(state_phase, progress[:states][state.to_sym], state_progress)
    progress[:states][state.to_sym] = state_hash
    progress[:current_description] = state_settings[state.to_sym][:description] if state_phase == :on_entry && state_settings[state.to_sym][:description].present?
    progress[:percent] += state_hash[:percent] * state_settings[state.to_sym][:weight] / 100.0 if state_settings[state.to_sym][:weight].present?
    migration_task.update_transformation_progress(progress)
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
    return false if state_settings[state.to_sym][:max_retries].nil?

    retries = "retries_#{state}".to_sym
    context[retries] = (context[retries] || 0) + 1
    context[retries] > state_settings[state.to_sym][:max_retries]
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

  # This transition simply allows to officially mark the task as migrating.
  # Temporarily, it also hands over to Automate.
  def start
    migration_task.update!(:state => 'migrate')
    handover_to_automate
    queue_signal(:poll_automate_state_machine)
  end

  def collapse_snapshots
    update_migration_task_progress(:on_entry)
    raise 'Collapsing snapshots timed out' if polling_timeout

    if context[:async_task_id_collapsing_snapshots].nil?
      if migration_task.source.supports_remove_all_snapshots?
        context[:async_task_id_collapsing_snapshots] = migration_task.source.remove_all_snapshots_queue(migration_task.userid.to_i)
      else
        update_migration_task_progress(:on_exit)
        return queue_signal(:poll_automate_state_machine)
      end
    end

    async_task = MiqTask.find(context[:async_task_id_collapsing_snapshots])

    if async_task.state == MiqTask::STATE_FINISHED
      if async_task.status == MiqTask::STATUS_OK
        update_migration_task_progress(:on_exit)
        return queue_signal(:poll_automate_state_machine)
      end
      raise async_task.message
    end

    update_migration_task_progress(:on_retry)
    queue_signal(:collapse_snapshots, :deliver_on => Time.now.utc + state_retry_interval)
  rescue StandardError => error
    update_migration_task_progress(:on_error)
    abort_conversion(error.message, 'error')
  end

  def poll_automate_state_machine
    return abort_conversion('Polling timed out', 'error') if polling_timeout

    message = "Migration Task vm=#{migration_task.source.name}, state=#{migration_task.state}, status=#{migration_task.status}"
    _log.info(prep_message(message))
    update(:message => message)
    if migration_task.state == 'finished'
      self.status = migration_task.status
      queue_signal(:finish)
    else
      queue_signal(:poll_automate_state_machine, :deliver_on => Time.now.utc + state_retry_interval)
    end
  end
end
