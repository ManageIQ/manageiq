module MiqServer::WorkerManagement::Monitor::Stop
  extend ActiveSupport::Concern

  def stop_worker_queue(worker, monitor_reason = nil)
    MiqQueue.put_deprecated(
      :class_name  => my_server.class.name,
      :instance_id => my_server.id,
      :method_name => 'stop_worker',
      :args        => [worker.id, monitor_reason],
      :queue_name  => 'miq_server',
      :zone        => my_server.zone.name,
      :server_guid => my_server.guid
    )
  end

  def stop_worker(worker, monitor_reason = nil)
    w = find_worker(worker)
    return if w.nil?

    msg = "Stopping #{w.format_full_log_msg}, status [#{w.status}]..."
    _log.info(msg)
    MiqEvent.raise_evm_event_queue(my_server, "evm_worker_stop", :event_details => msg, :type => w.type)

    worker_set_monitor_status(w.pid, :waiting_for_stop)
    worker_set_monitor_reason(w.pid, monitor_reason)

    w.update(:status => MiqWorker::STATUS_STOPPING)

    if w.containerized_worker?
      w.stop_container
    elsif w.systemd_worker?
      w.stop_systemd_worker
    elsif w.pid
      Process.kill("TERM", w.pid)
    else
      _log.error("Failed to stop worker #{w.inspect}; pid is nil")
    end
  end
end
