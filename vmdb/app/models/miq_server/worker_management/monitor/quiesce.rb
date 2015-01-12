module MiqServer::WorkerManagement::Monitor::Quiesce
  extend ActiveSupport::Concern

  def workers_quiesced?
    # do a subset of the monitor_workers loop to allow for graceful exit
    self.heartbeat

    self.class.monitor_class_names.each do |class_name|
      self.check_not_responding(class_name)
      self.check_pending_stop(class_name)
      self.clean_worker_records(class_name)
    end

    return true if self.miq_workers.all? { |w| w.is_stopped? }

    if self.quiesce_workers_loop_timeout?
      killed_workers = []
      self.miq_workers.each do |w|
        w.kill
        worker_delete(w.pid)
        killed_workers << w
      end
      self.miq_workers.delete(*killed_workers) unless killed_workers.empty?
      return true
    end

    self.kill_timed_out_worker_quiesce
    return false
  end

  def quiesce_workers_loop
    log_prefix = "MIQ(MiqServer.quiesce_workers_loop)"
    $log.info("#{log_prefix} Stopping all active workers")

    @quiesce_started_on = Time.now.utc
    @worker_monitor_settings ||= {}
    @quiesce_loop_timeout = @worker_monitor_settings[:quiesce_loop_timeout] || 5.minutes
    worker_monitor_poll = (@worker_monitor_settings[:poll] || 1.seconds).to_i_with_method

    self.miq_workers.each { |w| stop_worker(w) }
    loop do
      self.reload # Reload from SQL this MiqServer AND its miq_workers association
      break if self.workers_quiesced?
      sleep worker_monitor_poll
    end
  end

  def quiesce_all_workers
    log_prefix = "MIQ(MiqServer.quiesce_all_workers)"
    self.quiesce_workers_loop

    # Mark all messages currently being worked on by the not responding server's workers as error
    $log.info("#{log_prefix} Cleaning all active messages being processed by MiqServer")
    self.miq_workers.each { |w| w.clean_active_messages }
  end

  def quiesce_workers_loop_timeout?
    log_prefix = "MIQ(MiqServer.quiesce_workers_loop_timeout?)"
    if Time.now.utc > (@quiesce_started_on + @quiesce_loop_timeout)
      $log.warn("#{log_prefix} Timed out after #{@quiesce_loop_timeout} seconds")
      return true
    end
    return false
  end

  def quiesce_timed_out?(allowance)
    Time.now.utc > (@quiesce_started_on + allowance)
  end
end
