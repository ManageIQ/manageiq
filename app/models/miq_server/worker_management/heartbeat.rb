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

  def update_worker_last_heartbeat(worker_pid)
    @workers_lock.synchronize(:EX) do
      @workers[worker_pid][:last_heartbeat] = Time.now.utc if @workers.key?(worker_pid)
    end unless @workers_lock.nil?
  end

  def worker_heartbeat(worker_pid, worker_class = nil, queue_name = nil)
    # Set the heartbeat in memory and consume a message
    worker_class = worker_class.constantize if worker_class.kind_of?(String)

    messages = []
    @workers_lock.synchronize(:EX) do
      worker_add(worker_pid)
      update_worker_last_heartbeat(worker_pid)
      h = @workers[worker_pid]
      messages           = h[:message] || []
      h[:message]        = nil
      h[:class] ||= worker_class
      h[:queue_name] ||= queue_name
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

  # Get the latest heartbeat between the SQL and memory (updated via DRb)
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
    ENV["WORKER_HEARTBEAT_METHOD"] == "file" ? workers_last_heartbeat_to_file(w) : workers_last_heartbeat_to_drb(w)
  end

  def workers_last_heartbeat_to_drb(w)
    @workers_lock.synchronize(:SH) do
      @workers.fetch_path(w.pid, :last_heartbeat)
    end
  end

  def workers_last_heartbeat_to_file(w)
    File.mtime(w.heartbeat_file).utc if File.exist?(w.heartbeat_file)
  end
end
