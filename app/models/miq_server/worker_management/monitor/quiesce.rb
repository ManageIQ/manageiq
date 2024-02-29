module MiqServer::WorkerManagement::Monitor::Quiesce
  extend ActiveSupport::Concern

  def workers_quiesced?
    # do a subset of the monitor_workers loop to allow for graceful exit
    check_pending_stop
    clean_worker_records

    return true if miq_workers.all?(&:is_stopped?)
    return false unless quiesce_workers_loop_timeout?

    remove_workers(miq_workers, &:kill)
    true
  end

  def quiesce_workers_loop
    _log.info("Stopping all active workers")

    @quiesce_started_on = Time.now.utc
    @worker_monitor_settings ||= {}
    @quiesce_loop_timeout = @worker_monitor_settings[:quiesce_loop_timeout] || 5.minutes
    worker_monitor_poll = (@worker_monitor_settings[:poll] || 1.second).to_i_with_method

    miq_workers.each do |w|
      if w.containerized_worker?
        w.delete_container_objects
      else
        stop_worker(w)
      end
    end

    loop do
      my_server.reload # Reload from SQL this MiqServer AND its miq_workers association
      my_server.heartbeat

      break if workers_quiesced?

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
