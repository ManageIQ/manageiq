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

  def monitor_workers
    # Clear the my_server cache so we can detect role and possibly other changes faster
    my_server.class.my_server_clear_cache

    sync_monitor

    # Sync the workers after sync'ing the child worker settings
    sync_workers

    MiqWorker.status_update_all

    cleanup_failed_workers
  end

  def sync_workers
    MiqWorkerType.worker_classes.each_with_object({}) do |klass, result|
      result[klass.name] = klass.sync_workers
      result[klass.name][:adds].each { |pid| worker_add(pid) unless pid.nil? }
    rescue => error
      _log.error("Failed to sync_workers for class: #{klass.name}: #{error}")
      _log.log_backtrace(error)
      next
    end
  end

  def cleanup_failed_workers
    check_pending_stop
    clean_worker_records
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

  def sync_monitor
    @last_sync ||= Time.now.utc
    sync_interval         = @worker_monitor_settings[:sync_interval] || 30.minutes
    sync_interval_reached = sync_interval.seconds.ago.utc > @last_sync
    roles_changed         = my_server.active_roles_changed?
    resync_needed         = roles_changed || sync_interval_reached

    roles_added, roles_deleted, _roles_unchanged = my_server.role_changes

    if resync_needed
      log_role_changes           if roles_changed
      sync_active_roles          if roles_changed
      set_active_role_flags      if roles_changed

      EvmDatabase.restart_failover_monitor_service if (roles_added | roles_deleted).include?("database_operations")

      reset_queue_messages       if roles_changed

      @last_sync = Time.now.utc
      notify_workers_of_config_change(@last_sync)
    end
  end

  def key_store
    @key_store ||= MiqMemcached.client(:namespace => "server_monitor")
  end

  def notify_workers_of_config_change(last_sync)
    key_store.set("last_config_change", last_sync)
  end
end
