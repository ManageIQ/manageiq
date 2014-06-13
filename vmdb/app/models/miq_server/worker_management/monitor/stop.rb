module MiqServer::WorkerManagement::Monitor::Stop
  extend ActiveSupport::Concern

  def clean_stop_worker_queue_items
    MiqQueue.destroy_all(
      :class_name  => self.class.name,
      :method_name => "stop_worker",
      :queue_name  => 'miq_server',
      :server_guid => self.guid
    )
  end

  def stop_worker_queue(worker, monitor_status = :waiting_for_stop, monitor_reason = nil)
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => 'stop_worker',
      :args        => [worker.id, monitor_status, monitor_reason],
      :queue_name  => 'miq_server',
      :zone        => self.zone.name,
      :server_guid => self.guid
    )
  end

  def stop_worker(worker, monitor_status = :waiting_for_stop, monitor_reason = nil)
    log_prefix = "MIQ(#{self.class.name}.stop_worker)"
    w = worker.kind_of?(Integer) ? self.miq_workers.find_by_id(worker) : worker

    if w.nil?
      $log.warn("#{log_prefix} Cannot find Worker <#{w.inspect}>")
      return
    end

    msg = "Stopping #{w.format_full_log_msg}, status [#{w.status}]..."
    $log.info("#{log_prefix} #{msg}")
    MiqEvent.raise_evm_event_queue(self, "evm_worker_stop", :event_details => msg, :type => w.type)

    worker_set_monitor_status(w.pid, monitor_status)
    worker_set_monitor_reason(w.pid, monitor_reason)

    if w.respond_to?(:terminate)
      w.terminate
    else
      w.update_attributes(:status => MiqWorker::STATUS_STOPPING)
      worker_set_message(w, 'exit')
    end

  end
end
