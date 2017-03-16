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
    signal(:poll_refresh)
  end

  def poll_refresh
    signal(:notify)
  end

  def notify
    signal(:finish)
  end

  alias initializing dispatch_start
  alias start        run_native_op
  alias finish       process_finished
  alias abort_job    process_abort
  alias cancel       process_cancel
  alias error        process_error
end
