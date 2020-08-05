module MiqServer::WorkerManagement::Monitor::Quiesce
  extend ActiveSupport::Concern

  def workers_quiesced?
    # do a subset of the monitor_workers loop to allow for graceful exit
    heartbeat

    check_not_responding
    check_pending_stop
    clean_worker_records

    return true if miq_workers.all?(&:is_stopped?)

    if self.quiesce_workers_loop_timeout?
      killed_workers = []
      miq_workers.each do |w|
        w.kill
        worker_delete(w.pid)
        killed_workers << w
      end
      miq_workers.delete(*killed_workers) unless killed_workers.empty?
      return true
    end

    false
  end

  def quiesce_workers_loop
    _log.info("Stopping all active workers")

    @quiesce_started_on = Time.now.utc
    @worker_monitor_settings ||= {}
    @quiesce_loop_timeout = @worker_monitor_settings[:quiesce_loop_timeout] || 5.minutes
    worker_monitor_poll = (@worker_monitor_settings[:poll] || 1.seconds).to_i_with_method

    miq_workers.each do |w|
      if w.containerized_worker?
        w.delete_container_objects
      else
        stop_worker(w)
      end
    end

    loop do
      reload # Reload from SQL this MiqServer AND its miq_workers association
      break if self.workers_quiesced?
      sleep worker_monitor_poll
    end
  end

  def quiesce_all_workers
    quiesce_workers_loop

    # Mark all messages currently being worked on by the not responding server's workers as error
    _log.info("Cleaning all active messages being processed by MiqServer")
    miq_workers.each(&:clean_active_messages)
  end

  def quiesce_workers_loop_timeout?
    if Time.now.utc > (@quiesce_started_on + @quiesce_loop_timeout)
      _log.warn("Timed out after #{@quiesce_loop_timeout} seconds")
      return true
    end
    false
  end
end
