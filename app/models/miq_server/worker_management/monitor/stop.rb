module MiqServer::WorkerManagement::Monitor::Stop
  extend ActiveSupport::Concern

  def clean_stop_worker_queue_items
    MiqQueue.where(
      :class_name  => self.class.name,
      :method_name => "stop_worker",
      :queue_name  => 'miq_server',
      :server_guid => guid
    ).destroy_all
  end

  def stop_worker_queue(worker, monitor_status = :waiting_for_stop, monitor_reason = nil)
    MiqQueue.put_deprecated(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'stop_worker',
      :args        => [worker.id, monitor_status, monitor_reason],
      :queue_name  => 'miq_server',
      :zone        => zone.name,
      :server_guid => guid
    )
  end

  def stop_worker(worker, monitor_status = :waiting_for_stop, monitor_reason = nil)
    w = worker.kind_of?(Integer) ? miq_workers.find_by(:id => worker) : worker

    if w.nil?
      _log.warn("Cannot find Worker <#{w.inspect}>")
      return
    end

    msg = "Stopping #{w.format_full_log_msg}, status [#{w.status}]..."
    _log.info(msg)
    MiqEvent.raise_evm_event_queue(self, "evm_worker_stop", :event_details => msg, :type => w.type)

    worker_set_monitor_status(w.pid, monitor_status)
    worker_set_monitor_reason(w.pid, monitor_reason)

    if w.containerized_worker?
      w.stop_container
    elsif w.systemd_worker?
      w.stop_systemd_worker
    elsif w.respond_to?(:terminate)
      w.terminate
    else
      w.update(:status => MiqWorker::STATUS_STOPPING)
      worker_set_message(w, 'exit')
    end
  end
end
