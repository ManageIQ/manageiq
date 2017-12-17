class EmbeddedAnsibleWorker < MiqWorker
  require_nested :Runner
  include_concern 'ObjectManagement'

  # Don't allow multiple ansible monitor workers to run at once
  self.include_stopping_workers_on_synchronize = true

  self.required_roles = ['embedded_ansible']

  def start_runner
    start_monitor_thread
    nil # return no pid
  end

  def start_monitor_thread
    fix_connection_pool

    t = Thread.new do
      begin
        self.class::Runner.start_worker(worker_options)
        # TODO: return supervisord pid
      rescue SystemExit
        # Because we're running in a thread on the Server
        # we need to intercept SystemExit and exit our thread,
        # not the main server thread!
        _log.info("SystemExit received, exiting monitoring Thread")
        Thread.exit
      end
    end

    t[:worker_class] = self.class.name
    t[:worker_id]    = id
    t
  end

  def kill
    thread = find_worker_thread_object

    if thread == Thread.main
      _log.warn("Cowardly refusing to kill the main thread.")
    elsif thread.nil?
      _log.info("The monitor thread for worker id: #{id} was not found, it must have already exited.")
    else
      _log.info("Exiting monitor thread...")
      thread.exit
    end
    destroy
  end

  def find_worker_thread_object
    Thread.list.detect do |t|
      t[:worker_id] == id && t[:worker_class] == self.class.name
    end
  end

  def status_update
    # don't monitor the memory/cpu usage of this process yet
    # If we don't have a pid of a process we want to monitor,super will catch an Errno::ESRCH and abort the worker
  end

  # Base class methods we override since we don't have a separate process.  We might want to make these opt-in features in the base class that this subclass can choose to opt-out.
  def release_db_connection; end

  private

  def fix_connection_pool
    # If we only have one connection in the pool, it will be being used by the server
    # Add another so we can start the worker thread
    current = ActiveRecord::Base.connection_pool.instance_variable_get(:@size)
    ActiveRecord::Base.connection_pool.instance_variable_set(:@size, 2) if current == 1
  end
end
