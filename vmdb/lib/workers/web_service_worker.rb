require 'workers/worker_base'

class WebServiceWorker < WorkerBase
  self.wait_for_worker_monitor = false

  def do_work
  end

  def do_before_work_loop
    @worker.release_db_connection

    # Since thin traps interrupts, log that we're going away and update our worker row
    at_exit { do_exit("Exit request received.") }
  end
end
