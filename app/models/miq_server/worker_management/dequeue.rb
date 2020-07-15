module MiqServer::WorkerManagement::Dequeue
  extend ActiveSupport::Concern

  def peek(queue_name, priority, limit)
    MiqQueue.peek(
      :conditions => {:queue_name => queue_name, :priority => priority, :role => @active_role_names},
      :select     => "id, lock_version, priority, role",
      :limit      => limit
    )
  end

  def get_worker_dequeue_method(worker_class)
    (@child_worker_settings[worker_class.settings_name][:dequeue_method] || :drb).to_sym
  end

  def reset_queue_messages
    @queue_messages_lock.synchronize(:EX) do
      @queue_messages = {}
    end
  end

  def get_queue_priority_for_worker(w)
    w[:class].respond_to?(:queue_priority) ? w[:class].queue_priority : MiqQueue::MIN_PRIORITY
  end

  def get_queue_message_for_worker(w)
    return nil if w.nil? || w[:queue_name].nil?

    @queue_messages_lock.synchronize(:EX) do
      queue_name = w[:queue_name]
      queue_hash = @queue_messages[queue_name]
      return nil unless queue_hash.kind_of?(Hash)

      messages = queue_hash[:messages]
      return nil unless messages.kind_of?(Array)

      messages.each_index do |index|
        msg = messages[index]
        next if msg.nil?
        next if MiqQueue.lower_priority?(msg[:priority], get_queue_priority_for_worker(w))
        next unless w[:class].required_roles.blank? || msg[:role].blank? || Array.wrap(w[:class].required_roles).include?(msg[:role])
        return messages.delete_at(index)
      end

      return nil
    end
  end

  def get_queue_message(pid)
    @workers_lock.synchronize(:SH) do
      w = @workers[pid]

      msg = get_queue_message_for_worker(w)
      [msg[:id], msg[:lock_version]] if msg
    end unless @workers_lock.nil?
  end

  def prefetch_stale_threshold
    ::Settings.server.prefetch_stale_threshold.to_i_with_method
  end

  def prefetch_below_threshold?(queue_name, wcount)
    @queue_messages_lock.synchronize(:SH) do
      return false unless @queue_messages.key_path?(queue_name, :messages)
      return (@queue_messages[queue_name][:messages].length <= (::Settings.server.prefetch_min_per_worker_dequeue * wcount))
    end
  end

  def prefetch_stale?(queue_name)
    @queue_messages_lock.synchronize(:SH) do
      return true if @queue_messages[queue_name].nil?
      return ((Time.now.utc - @queue_messages[queue_name][:timestamp]) > prefetch_stale_threshold)
    end
  end

  def prefetch_has_lower_priority_than_miq_queue?(queue_name)
    @queue_messages_lock.synchronize(:SH) do
      return true if @queue_messages[queue_name].nil? || @queue_messages[queue_name][:messages].nil?
      msg = @queue_messages[queue_name][:messages].first
      return true if msg.nil?
      return peek(queue_name, MiqQueue.priority(msg[:priority], :higher, 1), 1).any?
    end
  end

  def get_worker_count_and_priority_by_queue_name
    queue_names = {}
    @workers_lock.synchronize(:SH) do
      @workers.each do |_pid, w|
        next if w[:queue_name].nil?
        next if w[:class].nil?
        next unless get_worker_dequeue_method(w[:class]) == :drb
        options = (queue_names[w[:queue_name]] ||= [0, MiqQueue::MAX_PRIORITY])
        options[0] += 1
        options[1]  = MiqQueue.lower_priority(get_queue_priority_for_worker(w), options[1])
      end
    end unless @workers_lock.nil?
    queue_names
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

  def populate_queue_messages
    queue_names = get_worker_count_and_priority_by_queue_name
    @queue_messages_lock.synchronize(:EX) do
      queue_names.each do |queue_name, (wcount, priority)|
        if prefetch_below_threshold?(queue_name, wcount) || prefetch_stale?(queue_name) || prefetch_has_lower_priority_than_miq_queue?(queue_name)
          @queue_messages[queue_name] ||= {}
          @queue_messages[queue_name][:timestamp] = Time.now.utc
          @queue_messages[queue_name][:messages]  = peek(queue_name, priority, (::Settings.server.prefetch_max_per_worker_dequeue * wcount)).collect do |q|
            {:id => q.id, :lock_version => q.lock_version, :priority => q.priority, :role => q.role}
          end
          _log.info("Fetched #{@queue_messages[queue_name][:messages].length} miq_queue rows for queue_name=#{queue_name}, wcount=#{wcount.inspect}, priority=#{priority.inspect}") if @queue_messages[queue_name][:messages].length > 0
        end
      end
    end
  end
end
