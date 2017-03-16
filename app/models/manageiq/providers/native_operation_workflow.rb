class ManageIQ::Providers::NativeOperationWorkflow < Job
  def self.create_job(options)
    super(name, options)
  end

  def load_transitions
    self.state ||= 'initialize'

    {
      :initializing     => {'initialize'       => 'waiting_to_start'},
      :start            => {'waiting_to_start' => 'running'},
      :poll_native_task => {'running'          => 'running'},
      :refresh          => {'running'          => 'refreshing'},
      :poll_refresh     => {'refreshing'       => 'refreshing'},
      :notify           => {'*'                => 'notifying'},
      :finish           => {'*'                => 'finished'},
      :abort_job        => {'*'                => 'aborting'},
      :cancel           => {'*'                => 'canceling'},
      :error            => {'*'                => '*'}
    }
  end

  def run_native_op
    raise NotImplementedError, _("run_native_op must be implemented by a subclass")
  end

  def poll_native_task
    raise NotImplementedError, _("poll_native_task must be implemented by a subclass")
  end

  def refresh
    target = target_entity

    task_ids = EmsRefresh.queue_refresh_task(target)

    context[:refresh_task_ids] = task_ids
    update_attributes!(:context => context)

    signal(:poll_refresh)
  end

  def poll_refresh
    refresh_finished = true

    context[:refresh_task_ids].each do |task_id|
      task = MiqTask.find(task_id)
      if task.state != MiqTask::STATE_FINISHED
        refresh_finished = false
        break
      end
    end

    if refresh_finished
      signal(:notify)
    else
      # TODO use queue_signal and deliver_on
      sleep(10)

      signal(:poll_refresh)
    end
  end

  def notify
    notification_options = {
      :target_name => target_entity.name,
      :method      => options[:method]
    }

    if status == "ok"
      type = :provider_operation_success
    else
      type = :provider_operation_failure
      notification_options[:error] = message
    end

    Notification.create(:type => type, :options => notification_options)

    signal(:finish)
  end

  alias initializing dispatch_start
  alias start        run_native_op
  alias finish       process_finished
  alias abort_job    process_abort
  alias cancel       process_cancel
end
