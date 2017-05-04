class ManageIQ::Providers::NativeOperationWorkflow < Job
  def self.create_job(options)
    super(name, options)
  end

  #
  # State-transition diagram:
  #
  #    *                          /------\
  #    | :initialize              |      |  :poll_native_task
  #    v               :start     v      |
  # waiting_to_start  -------> running ----------> refreshing <-\
  #                               |     :refresh        |       | :poll_refresh
  #                               v                     |-------/
  #                             error <-----------------|
  #                               |                     |
  #                               v                     |
  #       finished <---------- notifying --------------/
  #                   :finish              :notify
  #

  def run_native_op
    raise NotImplementedError, _("run_native_op must be implemented by a subclass")
  end

  def poll_native_task
    raise NotImplementedError, _("poll_native_task must be implemented by a subclass")
  end

  def refresh
    target = target_entity

    task_ids = EmsRefresh.queue_refresh_task(target)
    if task_ids.blank?
      process_error("Failed to queue refresh", "error")
      queue_signal(:notify)
    else
      context[:refresh_task_ids] = task_ids
      update_attributes!(:context => context)

      queue_signal(:poll_refresh)
    end
  end

  def poll_refresh
    if refresh_finished?
      queue_signal(:notify)
    else
      queue_signal(:poll_refresh, :deliver_on => Time.now.utc + 1.minute)
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

    queue_signal(:finish, message, status)
  end

  def queue_signal(*args, deliver_on: nil)
    role     = options[:role] || "ems_operations"
    priority = options[:priority] || MiqQueue::NORMAL_PRIORITY

    queue_options = {
      :class_name  => self.class.name,
      :method_name => "signal",
      :instance_id => id,
      :priority    => priority,
      :role        => role,
      :zone        => zone,
      :task_id     => guid,
      :args        => args,
      :deliver_on  => deliver_on
    }

    MiqQueue.put(queue_options)
  end

  alias initializing dispatch_start
  alias start        run_native_op
  alias finish       process_finished
  alias abort_job    process_abort
  alias cancel       process_cancel
  alias error        process_error

  protected

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

  def refresh_finished?
    context[:refresh_task_ids].each do |task_id|
      task = MiqTask.find(task_id)

      if task.status != MiqTask::STATUS_OK
        process_error("Refresh failed", "error")
      elsif task.state != MiqTask::STATE_FINISHED
        return false
      end
    end

    true
  end
end
