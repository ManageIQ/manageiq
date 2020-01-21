module MiqServer::WorkerManagement::Monitor
  extend ActiveSupport::Concern

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

    resync_needed = sync_needed?

    # Sync the workers after sync'ing the child worker settings
    sync_workers

    MiqWorker.status_update_all

    check_not_responding
    check_pending_stop
    clean_worker_records

    # Monitor all remaining current worker records
    miq_workers.where(:status => MiqWorker::STATUSES_CURRENT_OR_STARTING).each do |worker|
      # Push the heartbeat into the database
      persist_last_heartbeat(worker)
      # Check the worker record for heartbeat timeouts
      next unless validate_worker(worker)
      # Tell the valid workers to sync config if needed
      worker_set_message(worker, "sync_config") if resync_needed
    end

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
    MiqWorkerType.worker_class_names.each do |class_name|
      begin
        c = class_name.constantize
        raise NameError, "Constant problem: expected: #{class_name}, constantized: #{c.name}" unless c.name == class_name

        c.ensure_systemd_files if c.systemd_worker?
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

  def clean_worker_records
    worker_deleted = false
    miq_workers.each do |w|
      next unless w.is_stopped?
      _log.info("SQL Record for #{w.format_full_log_msg}, Status: [#{w.status}] is being deleted")
      worker_delete(w.pid)
      w.destroy
      worker_deleted = true
    end

    miq_workers.reload if worker_deleted
  end

  def check_pending_stop
    miq_workers.each do |w|
      next unless w.is_stopped?
      next unless worker_get_monitor_status(w.pid) == :waiting_for_stop
      worker_set_monitor_status(w.pid, nil)
    end
  end

  def check_not_responding
    return if MiqEnvironment::Command.is_podified?

    worker_deleted = false
    miq_workers.each do |w|
      next unless monitor_reason_not_responding?(w)
      next unless worker_get_monitor_status(w.pid) == :waiting_for_stop
      worker_not_responding(w)
      worker_delete(w.pid)
      w.destroy
      worker_deleted = true
    end

    miq_workers.reload if worker_deleted
  end

  def monitor_reason_not_responding?(w)
    [MiqServer::NOT_RESPONDING, MiqServer::MEMORY_EXCEEDED].include?(worker_get_monitor_reason(w.pid)) || w.stopping_for_too_long?
  end

  def do_system_limit_exceeded
    MiqWorkerType.worker_class_names_in_kill_order.each do |class_name|
      workers = class_name.constantize.find_current.to_a
      next if workers.empty?

      w = workers.sort_by { |w| [w.memory_usage || -1, w.id] }.last

      msg = "#{w.format_full_log_msg} is being stopped because system resources exceeded threshold, it will be restarted once memory has freed up"
      _log.warn(msg)
      MiqEvent.raise_evm_event_queue_in_region(w.miq_server, "evm_server_memory_exceeded", :event_details => msg, :type => w.class.name)
      stop_worker(w, MiqServer::MEMORY_EXCEEDED)
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

    roles_added, roles_deleted, _roles_unchanged = role_changes

    if resync_needed
      @last_sync = Time.now.utc

      sync_config                if config_changed
      sync_assigned_roles        if config_changed
      log_role_changes           if roles_changed
      sync_active_roles          if roles_changed
      set_active_role_flags      if roles_changed

      stop_apache                if roles_changed && !apache_needed?
      start_apache               if roles_changed &&  apache_needed?

      EvmDatabase.restart_failover_monitor_service if (roles_added | roles_deleted).include?("database_operations")

      reset_queue_messages       if config_changed || roles_changed

      update_sync_timestamp(@last_sync)
    end

    resync_needed
  end

  def set_last_change(key, value)
    key_store.set(key, value)
  end

  def key_store
    require 'dalli'
    @key_store ||= Dalli::Client.new(MiqMemcached.server_address, :namespace => "server_monitor")
  end

  def update_sync_timestamp(last_sync)
    set_last_change("last_config_change", last_sync)
  end
end
