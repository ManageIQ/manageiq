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
    log_prefix = "MIQ(MiqServer.monitor_workers)"

    resync_needed, sync_message = sync_needed?

    # Sync the workers after sync'ing the child worker settings
    self.sync_workers

    MiqWorker.status_update_all

    processed_worker_ids = []

    self.class.monitor_class_names.each do |class_name|
      processed_worker_ids += self.check_not_responding(class_name)
      processed_worker_ids += self.check_pending_stop(class_name)
      processed_worker_ids += self.clean_worker_records(class_name)
      processed_worker_ids += self.post_message_for_workers(class_name, resync_needed, sync_message)
    end

    validate_active_messages(processed_worker_ids)

    self.do_system_limit_exceeded if self.kill_workers_due_to_resources_exhausted?
  end

  def worker_not_responding(w)
    msg = "#{w.format_full_log_msg} being killed because it is not responding"
    $log.warn("#{self.log_prefix} #{msg}")
    MiqEvent.raise_evm_event_queue(w.miq_server, "evm_worker_killed", :event_details => msg, :type => w.class.name)
    w.kill
    MiqVimBrokerWorker.cleanup_for_pid(w.pid)
  end

  def sync_workers
    result = {}
    self.class.monitor_class_names.each do |class_name|
      c = class_name.constantize
      result[c.name] = c.sync_workers
      result[c.name][:adds].each { |pid| worker_add(pid) unless pid.nil? }
    end
    result
  end

  def restart_worker(w, reason = nil)
    stop_worker(w, :waiting_for_stop_before_restart, reason)
  end

  def clean_worker_records(class_name = nil)
    processed_workers = []
    self.miq_workers.each do |w|
      next unless class_name.nil? || (w.type == class_name)
      next unless w.is_stopped?
      next if worker_get_monitor_status(w.pid) == :pending_restart
      $log.info("#{self.log_prefix} SQL Record for #{w.format_full_log_msg}, Status: [#{w.status}] is being deleted")
      processed_workers << w
      worker_delete(w.pid)
      w.destroy
    end
    self.miq_workers.delete(*processed_workers) unless processed_workers.empty?
    processed_workers.collect(&:id)
  end

  def check_pending_stop(class_name = nil)
    processed_worker_ids = []
    self.miq_workers.each do |w|
      next unless class_name.nil? || (w.type == class_name)
      next unless w.is_stopped?
      next unless [:waiting_for_stop_before_restart, :waiting_for_stop].include?(worker_get_monitor_status(w.pid))
      worker_set_monitor_status(w.pid, nil)
      processed_worker_ids << w.id
    end
    processed_worker_ids
  end

  def check_not_responding(class_name = nil)
    processed_workers = []
    self.miq_workers.each do |w|
      next unless class_name.nil? || (w.type == class_name)
      next unless [:not_responding, :memory_exceeded].include?(worker_get_monitor_reason(w.pid))
      next unless [:waiting_for_stop_before_restart, :waiting_for_stop].include?(worker_get_monitor_status(w.pid))
      processed_workers << w
      worker_not_responding(w)
      worker_delete(w.pid)
    end
    self.miq_workers.delete(*processed_workers) unless processed_workers.empty?
    processed_workers.collect(&:id)
  end

  def do_system_limit_exceeded
    self.class.monitor_class_names_in_kill_order.each do |class_name|
      workers = class_name.constantize.find_current
      next if workers.empty?

      key = workers.first.memory_usage.nil? ? "id" : "memory_usage"
      # sorting an array of objects by an attribute that could be nil
      workers.sort! { |a,b| ( a[key] && b[key] ) ? ( a[key] <=> b[key] ) : ( a[key] ? -1 : 1 ) }

      w = workers.last
      msg = "#{w.format_full_log_msg} is being stopped because system resources exceeded threshold, it will be restarted once memory has freed up"
      $log.warn("#{self.log_prefix} #{msg}")
      MiqEvent.raise_evm_event_queue_in_region(w.miq_server, "evm_server_memory_exceeded", :event_details => msg, :type => w.class.name)
      self.restart_worker(w, :memory_exceeded)
      break
    end
  end

  def sync_needed?
    @last_sync          ||= Time.now.utc
    sync_interval         = @worker_monitor_settings[:sync_interval] || 30.minutes
    sync_interval_reached = sync_interval.seconds.ago.utc > @last_sync
    config_changed        = self.sync_config_changed?
    roles_changed         = self.active_roles_changed?
    resync_needed         = config_changed || roles_changed || sync_interval_reached
    sync_message          = nil

    if resync_needed
      @last_sync = Time.now.utc
      if (config_changed && roles_changed) || sync_interval_reached
        sync_message = "sync_active_roles_and_config"
      elsif config_changed
        sync_message = "sync_config"
      else
        sync_message = "sync_active_roles"
      end

      self.set_assigned_roles         if config_changed
      self.log_role_changes           if roles_changed
      self.sync_active_roles          if roles_changed
      self.set_active_role_flags      if roles_changed
      self.stop_apache                if roles_changed && !apache_needed?

      self.sync_config                if config_changed
      self.reset_queue_messages       if config_changed || roles_changed
    end

    return resync_needed, sync_message
  end

end
