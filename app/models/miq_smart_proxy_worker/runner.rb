class MiqSmartProxyWorker::Runner < MiqQueueWorkerBase::Runner
  def before_exit(message, _exit_code)
    @exit_requested = true
    #
    # Stop the Heartbeat Thread
    #
    safe_log("#{message} Stopping Heartbeat Thread.")

    #
    # Wait for the Heartbeat Thread to stop
    #
    if @tid
      safe_log("#{message} Waiting for Heartbeat Thread to Stop.")
      begin
        @tid.join(worker_settings[:heartbeat_thread_shutdown_timeout])
      rescue NoMethodError => join_err
        safe_log(join_err)
      end
    end
  end

  def start_heartbeat_thread
    @exit_requested    = false
    @heartbeat_started = Concurrent::Event.new
    _log.info("#{log_prefix} Starting Heartbeat Thread")

    tid = Thread.new do
      begin
        heartbeat_thread
      rescue => err
        _log.error("#{log_prefix} Heartbeat Thread aborted because [#{err.message}]")
        _log.log_backtrace(err)
        Thread.exit
      ensure
        @heartbeat_started.set
      end
    end

    @heartbeat_started.wait
    _log.info("#{log_prefix} Started Heartbeat Thread")

    tid
  end

  def heartbeat_thread
    @heartbeat_started.set
    until @exit_requested
      heartbeat
      sleep 30
    end
  end

  def ensure_heartbeat_thread_started
    # start the thread and return if it has not been started yet
    if @tid.nil?
      @tid = start_heartbeat_thread
      return
    end

    # if the thread is dead, start a new one and kill it if it is aborting
    if !@tid.alive?
      @tid.kill if @tid.status == "aborting"

      _log.info("#{log_prefix} Heartbeat Thread gone. Restarting...")
      @tid = start_heartbeat_thread
    end
  end

  def do_work
    ensure_heartbeat_thread_started
    super
  end
end
