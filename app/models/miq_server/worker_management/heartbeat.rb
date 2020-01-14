module MiqServer::WorkerManagement::Heartbeat
  extend ActiveSupport::Concern

  def worker_add_message(pid, item)
    @workers_lock.synchronize(:EX) do
      if @workers.key?(pid)
        @workers[pid][:message] ||= []
        @workers[pid][:message] << item  unless @workers[pid][:message].include?(item)
      end
    end unless @workers_lock.nil?
  end

  def register_worker(worker_pid, worker_class, queue_name)
    worker_class = worker_class.constantize if worker_class.kind_of?(String)

    @workers_lock.synchronize(:EX) do
      worker_add(worker_pid)
      h = @workers[worker_pid]
      h[:class] ||= worker_class
      h[:queue_name] ||= queue_name
    end unless @workers_lock.nil?
  end

  def worker_get_messages(worker_pid)
    messages = []
    @workers_lock.synchronize(:EX) do
      h = @workers[worker_pid]
      if h
        messages    = h[:message] || []
        h[:message] = nil
      end
    end unless @workers_lock.nil?

    messages
  end

  def worker_set_message(w, message, *args)
    _log.info("#{w.format_full_log_msg} is being requested to #{message}")
    @workers_lock.synchronize(:EX) do
      worker_add_message(w.pid, [message, *args]) if @workers.key?(w.pid)
    end unless @workers_lock.nil?
  end

  def message_for_worker(wid, message, *args)
    w = MiqWorker.find_by(:id => wid)
    worker_set_message(w, message, *args) unless w.nil?
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
