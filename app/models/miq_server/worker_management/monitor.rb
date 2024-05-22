module MiqServer::WorkerManagement::Monitor
  extend ActiveSupport::Concern

  include Kill
  include Quiesce
  include Reason
  include Settings
  include Start
  include Status
  include Stop
  include SystemLimits
  include Validation

  def monitor_workers
    # Reload my_server so we can detect role and possibly other changes faster
    my_server.reload

    # Cache a list of the native objects backing the miq_workers (e.g.: pods, services, or processes)
    sync_from_system

    sync_monitor

    # Sync the workers after sync'ing the child worker settings
    sync_workers

    MiqWorker.status_update_all

    cleanup_failed_workers
  end

  def worker_not_responding(w)
    msg = "#{w.format_full_log_msg} being killed because it is not responding"
    _log.warn(msg)
    MiqEvent.raise_evm_event_queue(w.miq_server, "evm_worker_killed", :event_details => msg, :type => w.class.name)
    w.kill
  end

  def sync_workers
    MiqWorkerType.worker_classes.each do |klass|
      synced_workers = klass.sync_workers
      synced_workers[:adds].each { |pid| worker_add(pid) unless pid.nil? }
    rescue => error
      _log.error("Failed to sync_workers for class: #{klass.name}: #{error}")
      _log.log_backtrace(error)
      next
    end

    sync_starting_workers
    sync_stopping_workers
  end

  def cleanup_failed_workers
    check_pending_stop
    clean_worker_records
  end

  def clean_worker_records
    remove_workers(miq_workers.to_a.select(&:is_stopped?)) do |w|
      _log.info("SQL Record for #{w.format_full_log_msg}, Status: [#{w.status}] is being deleted")
    end
  end

  def check_pending_stop
    miq_workers.each do |w|
      next unless w.is_stopped?
      next unless worker_get_monitor_status(w.pid) == :waiting_for_stop

      worker_set_monitor_status(w.pid, nil)
    end
  end

  def monitor_reason_not_responding?(w)
    [MiqServer::WorkerManagement::NOT_RESPONDING, MiqServer::WorkerManagement::MEMORY_EXCEEDED].include?(worker_get_monitor_reason(w.pid)) || w.stopping_for_too_long?
  end

  def do_system_limit_exceeded
    MiqWorkerType.worker_classes_in_kill_order.each do |worker_class|
      workers = worker_class.find_current.to_a
      next if workers.empty?

      w = workers.sort_by { |w| [w.memory_usage || -1, w.id] }.last

      msg = "#{w.format_full_log_msg} is being stopped because system resources exceeded threshold, it will be restarted once memory has freed up"
      _log.warn(msg)

      notification_options = {
        :name             => my_server.name,
        :memory_usage     => my_server.memory_usage.to_i,
        :memory_threshold => my_server.memory_threshold,
        :pid              => my_server.pid
      }

      MiqEvent.raise_evm_event_queue_in_region(w.miq_server, "evm_server_memory_exceeded", :event_details => msg, :type => w.class.name, :full_data => notification_options)
      stop_worker(w, MiqServer::WorkerManagement::MEMORY_EXCEEDED)
      break
    end
  end

  def sync_monitor
    @last_sync          ||= Time.now.utc
    sync_interval         = @worker_monitor_settings[:sync_interval] || 30.minutes
    sync_interval_reached = sync_interval.seconds.ago.utc > @last_sync

    if sync_interval_reached
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
