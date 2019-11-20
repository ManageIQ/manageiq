module MiqServer::WorkerManagement::Monitor::Start
  extend ActiveSupport::Concern

  def wait_for_started_poll
    (@worker_monitor_settings[:wait_for_started_poll] || 10.seconds).to_i_with_method
  end

  def wait_for_started_workers
    last_which                    = nil
    entered_wait_for_started_loop = Time.now.utc
    wait_for_started_timeout      = @worker_monitor_settings[:wait_for_started_timeout] || 10.minutes
    loop do
      starting = MiqWorker.find_starting.find_all { |w| MiqWorkerType.worker_class_names.include?(w.class.name) }
      if starting.empty?
        _log.info("All workers have been started")
        break
      end

      if wait_for_started_timeout.seconds.ago.utc > entered_wait_for_started_loop
        _log.warn("After waiting #{wait_for_started_timeout} seconds, no longer waiting for the following workers to start:")
        starting.each { |w| $log.warn("Worker type: #{w.class.name}, pid: #{w.pid}, guid: #{w.guid}, status: #{w.status}") }
        break
      end

      which = ""
      starting = starting.collect { |w| w.class.name }.sort
      until starting.empty?
        c, n = starting.first, 0
        c, n = starting.shift, n + 1 while c == starting.first
        which << "#{c} (#{n}), "
      end
      which.chomp!(", ")

      if which != last_which
        _log.info("Waiting for the following workers to start: #{which}")
        last_which = which
      end

      sleep wait_for_started_poll
    end
  end
end
