class EmbeddedAnsibleWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ['embedded_ansible']

  def start_runner
    Thread.new do
      begin
        self.class::Runner.start_worker(worker_options)
        # TODO: return supervisord pid
      rescue SystemExit
        # Because we're running in a thread on the Server
        # we need to intercept SystemExit and exit our thread,
        # not the main server thread!
        log.info("#{log_prefix} SystemExit received, exiting monitoring Thread")
        Thread.exit
      end
    end
  end

  def kill
    stop
  end

  def status_update
    # don't monitor the memory/cpu usage of this process yet
    # If we don't have a pid of a process we want to monitor,super will catch an Errno::ESRCH and abort the worker
  end

  # Base class methods we override since we don't have a separate process.  We might want to make these opt-in features in the base class that this subclass can choose to opt-out.
  def release_db_connection; end
end
