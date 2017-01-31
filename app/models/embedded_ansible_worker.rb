class EmbeddedAnsibleWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ['embedded_ansible']

  def start_runner
    self.class::Runner.start_worker(worker_options)
    # TODO: return supervisord pid
  end

  def kill
    # Does the base class's kill -9 work on the supervisord process as we want?
  end

  def status_update
    # don't monitor the memory/cpu usage of this process yet
    # If we don't have a pid of a process we want to monitor,super will catch an Errno::ESRCH and abort the worker
  end

  # Base class methods we override since we don't have a separate process.  We might want to make these opt-in features in the base class that this subclass can choose to opt-out.
  def release_db_connection; end
end
