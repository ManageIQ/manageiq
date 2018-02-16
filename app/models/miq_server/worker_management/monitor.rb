module MiqServer::WorkerManagement::Monitor
  extend ActiveSupport::Concern

  include_concern 'ClassNames'
  include_concern 'Kill'
  include_concern 'Quiesce'
  include_concern 'Reason'
  include_concern 'Settings'
  include_concern 'Start'
  include_concern 'Status'
  include_concern 'Stop'
  include_concern 'SystemLimits'
  include_concern 'Validation'

  def monitor_workers
    # Clear the my_server cache so we can detect role and possibly other changes faster
    self.class.my_server_clear_cache

    resync_needed, sync_message = sync_needed?

    # Sync the workers after sync'ing the child worker settings
    sync_workers

    MiqWorker.status_update_all

    processed_worker_ids = []

    self.class.monitor_class_names.each do |class_name|
      processed_worker_ids += check_not_responding(class_name)
      processed_worker_ids += check_pending_stop(class_name)
      processed_worker_ids += clean_worker_records(class_name)
      processed_worker_ids += post_message_for_workers(class_name, resync_needed, sync_message)
    end

    validate_active_messages(processed_worker_ids)

    do_system_limit_exceeded if self.kill_workers_due_to_resources_exhausted?
  end

  def worker_not_responding(w)
    msg = "#{w.format_full_log_msg} being killed because it is not responding"
    _log.warn(msg)
    MiqEvent.raise_evm_event_queue(w.miq_server, "evm_worker_killed", :event_details => msg, :type => w.class.name)
    w.kill
    MiqVimBrokerWorker.cleanup_for_pid(w.pid)
  end

  def sync_workers
    result = {}
    self.class.monitor_class_names.each do |class_name|
      begin
        c = class_name.constantize
        result[c.name] = c.sync_workers
        result[c.name][:adds].each { |pid| worker_add(pid) unless pid.nil? }
      rescue => error
        _log.error("Failed to sync_workers for class: #{class_name}")
        _log.log_backtrace(error)
        next
      end
    end
    result
  end

  def restart_worker(w, reason = nil)
    stop_worker(w, :waiting_for_stop_before_restart, reason)
  end

  def clean_worker_records(class_name = nil)
    processed_workers = []
    miq_workers.each do |w|
      next unless class_name.nil? || (w.type == class_name)
      next unless w.is_stopped?
      _log.info("SQL Record for #{w.format_full_log_msg}, Status: [#{w.status}] is being deleted")
      processed_workers << w
      worker_delete(w.pid)
      w.destroy
    end
    miq_workers.delete(*processed_workers) unless processed_workers.empty?
    processed_workers.collect(&:id)
  end

  def check_pending_stop(class_name = nil)
    processed_worker_ids = []
    miq_workers.each do |w|
      next unless class_name.nil? || (w.type == class_name)
      next unless w.is_stopped?
      next unless [:waiting_for_stop_before_restart, :waiting_for_stop].include?(worker_get_monitor_status(w.pid))
      worker_set_monitor_status(w.pid, nil)
      processed_worker_ids << w.id
    end
    processed_worker_ids
  end

  def check_not_responding(class_name = nil)
    return [] if MiqEnvironment::Command.is_container?
    processed_workers = []
    miq_workers.each do |w|
      next unless class_name.nil? || (w.type == class_name)
      next unless monitor_reason_not_responding?(w)
      next unless [:waiting_for_stop_before_restart, :waiting_for_stop].include?(worker_get_monitor_status(w.pid))
      processed_workers << w
      worker_not_responding(w)
      worker_delete(w.pid)
    end
    miq_workers.delete(*processed_workers) unless processed_workers.empty?
    processed_workers.collect(&:id)
  end

  def monitor_reason_not_responding?(w)
    [MiqServer::NOT_RESPONDING, MiqServer::MEMORY_EXCEEDED].include?(worker_get_monitor_reason(w.pid)) || w.stopping_for_too_long?
  end

  def do_system_limit_exceeded
    self.class.monitor_class_names_in_kill_order.each do |class_name|
      workers = class_name.constantize.find_current.to_a
      next if workers.empty?

      w = workers.sort_by { |w| [w.memory_usage || -1, w.id] }.last

      msg = "#{w.format_full_log_msg} is being stopped because system resources exceeded threshold, it will be restarted once memory has freed up"
      _log.warn(msg)
      MiqEvent.raise_evm_event_queue_in_region(w.miq_server, "evm_server_memory_exceeded", :event_details => msg, :type => w.class.name)
      restart_worker(w, MiqServer::MEMORY_EXCEEDED)
      break
    end
  end

  def sync_needed?
    @last_sync ||= Time.now.utc
    sync_interval         = @worker_monitor_settings[:sync_interval] || 30.minutes
    sync_interval_reached = sync_interval.seconds.ago.utc > @last_sync
    config_changed        = self.sync_config_changed?
    roles_changed         = self.active_roles_changed?
    resync_needed         = config_changed || roles_changed || sync_interval_reached
    sync_message          = nil

    if resync_needed
      @last_sync = Time.now.utc
      sync_message = "sync_config"

      sync_config                if config_changed
      sync_assigned_roles        if config_changed
      log_role_changes           if roles_changed
      sync_active_roles          if roles_changed
      set_active_role_flags      if roles_changed

      stop_apache                if roles_changed && !apache_needed?
      start_apache               if roles_changed &&  apache_needed?

      reset_queue_messages       if config_changed || roles_changed

      update_sync_timestamp(@last_sync)
    end

    return resync_needed, sync_message
  end

  def set_last_change(key, value)
    key_store.set(key, value)
  end

  def key_store
    @key_store ||= Dalli::Client.new(MiqMemcached.server_address, :namespace => "server_monitor")
  end

  def update_sync_timestamp(last_sync)
    set_last_change("last_config_change", last_sync)
  end
end
