module MiqServer::WorkerManagement::Monitor
  extend ActiveSupport::Concern

  include_concern 'Kill'
  include_concern 'Kubernetes'
  include_concern 'Quiesce'
  include_concern 'Reason'
  include_concern 'Settings'
  include_concern 'Start'
  include_concern 'Status'
  include_concern 'Stop'
  include_concern 'Systemd'
  include_concern 'SystemLimits'
  include_concern 'Validation'

  def monitor_workers
    # Clear the my_server cache so we can detect role and possibly other changes faster
    self.class.my_server_clear_cache

    sync_from_system
    sync_monitor

    # Sync the workers after sync'ing the child worker settings
    sync_workers

    MiqWorker.status_update_all

    cleanup_failed_workers

    # Monitor all remaining current worker records
    miq_workers.where(:status => MiqWorker::STATUSES_CURRENT_OR_STARTING).each do |worker|
      # Push the heartbeat into the database
      persist_last_heartbeat(worker)
      # Check the worker record for heartbeat timeouts
      next unless validate_worker(worker)
    end

    do_system_limit_exceeded if self.kill_workers_due_to_resources_exhausted?
  end

  def worker_not_responding(w)
    msg = "#{w.format_full_log_msg} being killed because it is not responding"
    _log.warn(msg)
    MiqEvent.raise_evm_event_queue(w.miq_server, "evm_worker_killed", :event_details => msg, :type => w.class.name)
    w.kill
  end

  def sync_workers
    result = {}
    MiqWorkerType.worker_class_names.each do |class_name|
      begin
        c = class_name.constantize
        raise NameError, "Constant problem: expected: #{class_name}, constantized: #{c.name}" unless c.name == class_name

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

  def sync_from_system
    if podified?
      ensure_kube_monitors_started
    end

    cleanup_orphaned_worker_rows

    if podified?
      sync_deployment_settings
    end
  end

  def cleanup_orphaned_worker_rows
    if podified?
      # TODO: Move to a method in the kubernetes namespace
      unless current_pods.empty?
        orphaned_rows = podified_miq_workers.where.not(:system_uid => current_pods.keys)
        unless orphaned_rows.empty?
          _log.warn("Removing orphaned worker rows without corresponding pods: #{orphaned_rows.collect(&:system_uid).inspect}")
          orphaned_rows.destroy_all
        end
      end
    end
  end

  def cleanup_failed_workers
    check_not_responding
    check_pending_stop
    clean_worker_records

    if podified?
      cleanup_failed_deployments
    elsif systemd?
      cleanup_failed_systemd_services
    end
  end

  def podified?
    MiqEnvironment::Command.is_podified?
  end

  def systemd?
    MiqEnvironment::Command.supports_systemd?
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

      notification_options = {
        :name             => name,
        :memory_usage     => memory_usage.to_i,
        :memory_threshold => memory_threshold,
        :pid              => pid
      }

      MiqEvent.raise_evm_event_queue_in_region(w.miq_server, "evm_server_memory_exceeded", :event_details => msg, :type => w.class.name, :full_data => notification_options)
      stop_worker(w, MiqServer::MEMORY_EXCEEDED)
      break
    end
  end

  def sync_monitor
    @last_sync ||= Time.now.utc
    sync_interval         = @worker_monitor_settings[:sync_interval] || 30.minutes
    sync_interval_reached = sync_interval.seconds.ago.utc > @last_sync
    roles_changed         = self.active_roles_changed?
    resync_needed         = roles_changed || sync_interval_reached

    roles_added, roles_deleted, _roles_unchanged = role_changes

    if resync_needed
      log_role_changes           if roles_changed
      sync_active_roles          if roles_changed
      set_active_role_flags      if roles_changed

      stop_apache                if roles_changed && !apache_needed?
      start_apache               if roles_changed &&  apache_needed?

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
