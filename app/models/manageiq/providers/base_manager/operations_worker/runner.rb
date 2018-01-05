class ManageIQ::Providers::BaseManager::OperationsWorker::Runner < ::MiqWorker::Runner
  OPTIONS_PARSER_SETTINGS = ::MiqWorker::Runner::OPTIONS_PARSER_SETTINGS + [
    [:ems_id, 'EMS Instance ID', String],
  ]

  def after_initialize
    @ems = ExtManagementSystem.find(@cfg[:ems_id])
    @operations_klass = @ems.class::Operations

    do_exit("Unable to find instance for EMS ID [#{@cfg[:ems_id]}].", 1) if @ems.nil?
    do_exit("EMS ID [#{@cfg[:ems_id]}] failed authentication check.", 1) unless @ems.authentication_check.first
  end

  def do_before_work_loop
    start_operations_thread
  end

  def before_exit(message, _exit_code)
    #
    # Stop the Operations thread
    #
    safe_log("#{message} Stopping Operations Thread.")
    stop_operations_thread

    #
    # Wait for the thread to stop cleanly (timeout after 10 seconds)
    #
    unless operations_thread.nil?
      safe_log("#{message} Waiting for Operations Thread to exit...")
      operations_thread.join(worker_settings[:thread_shutdown_timeout])
      safe_log("#{message} Waiting for Operations Thread to exit...Complete")
    end
  end

  def do_work
    return if operations_thread_alive?

    _log.info("Restarting operations thread...")
    start_operations_thread
    _log.info("Restarting operations thread...Complete")
  end

  private

  attr_reader :ems, :operations_klass, :operations_thread

  def start_operations_thread
    _log.info("Operations thread starting...")
    thread_started = Concurrent::Event.new

    @operations_thread = Thread.new do
      begin
        operations_klass.run! { thread_started.set }
      rescue => err
        _log.error("Operations thread aborted because [#{err.message}]")
        _log.log_backtrace(err)
        Thread.exit
      end
    end

    thread_started.wait

    _log.info("Operations thread starting...Complete")
  end

  def stop_operations_thread
    # TODO
  end

  def operations_thread_alive?
    !operations_thread.nil? && operations_thread.alive?
  end
end
