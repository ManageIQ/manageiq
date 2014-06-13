module MiqServer::WorkerManagement::Heartbeat
  extend ActiveSupport::Concern

  def worker_add_message(pid, item)
    @workers_lock.synchronize(:EX) do
      if @workers.has_key?(pid)
        @workers[pid][:message] ||= []
        @workers[pid][:message]  << item  unless @workers[pid][:message].include?(item)
      end
    end unless @workers_lock.nil?
  end

  def update_worker_last_heartbeat(worker_pid)
    @workers_lock.synchronize(:EX) do
      @workers[worker_pid][:last_heartbeat] = Time.now.utc if @workers.has_key?(worker_pid)
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
      h[:class]        ||= worker_class
      h[:queue_name]   ||= queue_name
    end unless @workers_lock.nil?

    # Special process the sync_ messages to send the current values of what to synchronize
    messages.collect do |message, *args|
      case message
      when "sync_config"
        [message, {:config => @vmdb_config}]
      when "sync_active_roles"
        [message, {:roles  => @active_role_names}]
      else
        [message, *args]
      end
    end
  end

  def worker_set_message(w, message, *args)
    # Special process for this compound message, by breaking it up into 2 simpler messages
    if message == 'sync_active_roles_and_config'
      worker_set_message(w, 'sync_active_roles')
      worker_set_message(w, 'sync_config')
      return
    end

    $log.info("MIQ(MiqServer.worker_set_message) #{w.format_full_log_msg} is being requested to #{message}")
    @workers_lock.synchronize(:EX) do
      worker_add_message(w.pid, [message, *args]) if @workers.has_key?(w.pid)
    end unless @workers_lock.nil?
  end

  def message_for_worker(wid, message, *args)
    w = MiqWorker.find_by_id(wid)
    worker_set_message(w, message, *args) unless w.nil?
  end

  def post_message_for_workers(class_name = nil, resync_needed = false, sync_message = nil)
    processed_worker_ids = []
    self.miq_workers.each do |w|
      next unless class_name.nil? || (w.type == class_name)
      next unless MiqWorker::STATUSES_CURRENT_OR_STARTING.include?(w.status)
      processed_worker_ids << w.id
      next unless self.validate_worker(w)
      worker_set_message(w, sync_message) if resync_needed
    end
    processed_worker_ids
  end

  # Get the latest heartbeat between the SQL and memory (updated via DRb)
  def validate_heartbeat(w)
    if w.last_heartbeat.nil?
      w.last_heartbeat ||= @workers[w.pid][:last_heartbeat] if @workers.has_key?(w.pid)
      w.last_heartbeat ||= Time.now.utc
    else
      if @workers.has_key?(w.pid) && !@workers[w.pid][:last_heartbeat].nil? && @workers[w.pid][:last_heartbeat] > w.last_heartbeat
        w.update_attributes(:last_heartbeat => @workers[w.pid][:last_heartbeat])
      end
    end
  end

end
