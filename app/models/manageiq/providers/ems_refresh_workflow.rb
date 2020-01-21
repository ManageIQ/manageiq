class ManageIQ::Providers::EmsRefreshWorkflow < Job
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

  def run_native_op
    # a step before the refresh, can be overwritten by a subclass
    queue_signal(:refresh)
  end

  def poll_native_task
    raise NotImplementedError, _("poll_native_task must be implemented by a subclass")
  end

  def post_refresh
    # a step after the refresh, can be overwritten by a subclass
    queue_signal(:finish)
  end

  def refresh
    target = target_entity

    task_ids = EmsRefresh.queue_refresh_task(target)
    if task_ids.blank?
      process_error("Failed to queue refresh", "error")
      queue_signal(:error)
    else
      context[:refresh_task_ids] = task_ids
      update!(:context => context)

      queue_signal(:poll_refresh)
    end
  end

  def poll_refresh
    if refresh_finished?
      queue_signal(:post_refresh)
    else
      queue_signal(:poll_refresh, :deliver_on => Time.now.utc + 1.minute)
    end
  end

  def queue_signal(*args, deliver_on: nil)
    role     = options[:role] || "ems_operations"
    priority = options[:priority] || MiqQueue::NORMAL_PRIORITY

    super(*args, :role => role, :priority => priority, :deliver_on => deliver_on)
  end

  alias_method :initializing, :dispatch_start
  alias_method :start,        :run_native_op
  alias_method :finish,       :process_finished
  alias_method :abort_job,    :process_abort
  alias_method :cancel,       :process_cancel
  alias_method :error,        :process_error

  protected

  def load_transitions
    self.state ||= 'initialize'

    {
      :initializing     => {'initialize'       => 'waiting_to_start'},
      :start            => {'waiting_to_start' => 'running'},
      :poll_native_task => {'running'          => 'running'},
      :refresh          => {'running'          => 'refreshing'},
      :poll_refresh     => {'refreshing'       => 'refreshing'},
      :post_refresh     => {'refreshing'       => 'post_refreshing'},
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
