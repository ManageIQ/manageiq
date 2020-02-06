module MiqServer::WorkerManagement::Heartbeat
  extend ActiveSupport::Concern

  def register_worker(worker_pid, worker_class, queue_name)
    worker_class = worker_class.constantize if worker_class.kind_of?(String)

    @workers_lock.synchronize(:EX) do
      worker_add(worker_pid)
      h = @workers[worker_pid]
      h[:class] ||= worker_class
      h[:queue_name] ||= queue_name
    end unless @workers_lock.nil?
  end

  def persist_last_heartbeat(w)
    last_heartbeat = workers_last_heartbeat(w)

    if w.last_heartbeat.nil?
      last_heartbeat ||= Time.now.utc
      w.update(:last_heartbeat => last_heartbeat)
    elsif !last_heartbeat.nil? && last_heartbeat > w.last_heartbeat
      w.update(:last_heartbeat => last_heartbeat)
    end
  end

  def clean_heartbeat_files
    Dir.glob(Rails.root.join("tmp", "*.hb")).each { |f| File.delete(f) }
  end

  private

  def workers_last_heartbeat(w)
    File.mtime(w.heartbeat_file).utc if File.exist?(w.heartbeat_file)
  end
end
