class MiqScheduleWorker::Jobs
  def vmdb_appliance_log_config
    queue_work(:class_name  => "Vmdb::Appliance", :method_name => "log_config", :queue_name => 'miq_server', :server_guid => MiqServer.my_guid)
  end

  def miq_server_status_update
    # Needs to be run on the server process
    queue_work(:class_name  => "MiqServer", :method_name => "status_update", :queue_name => 'miq_server', :server_guid => MiqServer.my_guid, :priority => MiqQueue::HIGH_PRIORITY)
  end

  def miq_server_worker_log_status
    queue_work(:class_name  => "MiqServer", :method_name => "log_status",     :queue_name => 'miq_server', :task_id => "log_status", :server_guid => MiqServer.my_guid, :priority => MiqQueue::HIGH_PRIORITY)
    queue_work(:class_name  => "MiqWorker", :method_name => "log_status_all", :queue_name => 'miq_server', :task_id => "log_status", :server_guid => MiqServer.my_guid, :priority => MiqQueue::HIGH_PRIORITY)
  end

  def miq_server_audit_managed_resources
    queue_work(:class_name  => "MiqServer", :method_name => "report_audit_details", :queue_name => 'miq_server', :task_id => "report_audit_details", :server_guid => MiqServer.my_guid)
  end

  def vmdb_database_connection_log_statistics
    queue_work(:class_name  => "VmdbDatabaseConnection", :method_name => "log_statistics", :queue_name => 'miq_server', :server_guid => MiqServer.my_guid)
  end

  def job_check_jobs_for_timeout
    queue_work_on_each_zone(:class_name => "Job", :method_name => "check_jobs_for_timeout")
  end

  def retirement_check
    queue_work_on_each_zone(:class_name => 'RetirementManager', :method_name => 'check')
    queue_work(:class_name => 'RetirementManager', :method_name => 'check_per_region', :zone => nil)
  end

  def host_authentication_check_schedule
    queue_work_on_each_zone(:class_name  => "Host", :method_name => "authentication_check_schedule", :priority => MiqQueue::HIGH_PRIORITY)
  end

  def ems_authentication_check_schedule
    queue_work_on_each_zone(:class_name  => "ExtManagementSystem", :method_name => "authentication_check_schedule", :priority => MiqQueue::HIGH_PRIORITY)
  end

  def session_check_session_timeout
    queue_work(:class_name => "Session", :method_name => "check_session_timeout", :server_guid => MiqServer.my_guid)
  end

  def job_check_for_evm_snapshots(job_not_found_delay)
    queue_work_on_each_zone_with_active_role(
      "smartstate",
      :class_name  => "Job",
      :method_name => "check_for_evm_snapshots",
      :args        => [job_not_found_delay]
    )
  end

  def vm_scan_dispatcher_dispatch
    if VmScan::Dispatcher.waiting?
      queue_work_on_each_zone(:class_name => "VmScan::Dispatcher", :method_name => "dispatch", :task_id => "job_dispatcher", :priority => MiqQueue::HIGH_PRIORITY, :role => "smartstate")
    end
  end

  def container_scan_dispatcher_dispatch
    if ManageIQ::Providers::Kubernetes::ContainerManager::Scanning::Job::Dispatcher.waiting?
      queue_work_on_each_zone(:class_name => "ManageIQ::Providers::Kubernetes::ContainerManager::Scanning::Job::Dispatcher", :method_name => "dispatch", :task_id => "job_dispatcher", :priority => MiqQueue::HIGH_PRIORITY, :role => "smartstate")
    end
  end

  def image_import_dispatcher_dispatch
    if ManageIQ::Providers::ImageImportJob::Dispatcher.waiting?
      queue_work(:class_name => "ManageIQ::Providers::ImageImportJob::Dispatcher", :method_name => "dispatch", :task_id => "job_dispatcher", :priority => MiqQueue::HIGH_PRIORITY)
    end
  end

  def ems_refresh_timer(klass)
    queue_work_on_each_zone(:class_name  => klass.name, :method_name => "refresh_all_ems_timer") if klass.any?
  end

  def miq_alert_evaluate_hourly_timer
    queue_work_on_each_zone(:class_name  => "MiqAlert", :method_name => "evaluate_hourly_timer")
  end

  def storage_scan_timer
    queue_work(:class_name => "Storage", :method_name => "scan_timer")
  end

  def metric_capture_perf_capture_timer
    MiqServer.my_server.zone.ems_metrics_collectable.each do |ems|
      queue_work(
        :class_name  => "Metric::Capture",
        :method_name => "perf_capture_timer",
        :args        => [ems.id],
        :role        => "ems_metrics_coordinator",
        :state       => ["ready", "dequeue"]
      )
    end
  end

  def metric_purging_purge_realtime_timer
    queue_work(:class_name => "Metric::Purging", :method_name => "purge_realtime_timer", :zone => nil)
  end

  def metric_purging_purge_rollup_timer
    queue_work(:class_name => "Metric::Purging", :method_name => "purge_rollup_timer", :zone => nil)
  end

  def drift_state_purge_timer
    queue_work(:class_name => "DriftState", :method_name => "purge_timer", :zone => nil)
  end

  def audit_event_purge_timer
    queue_work(:class_name => "AuditEvent", :method_name => "purge_timer", :zone => nil)
  end

  def event_stream_purge_timer
    queue_work(:class_name => "EventStream", :method_name => "purge_timer", :zone => nil)
  end

  def notification_purge_timer
    queue_work(:class_name => "Notification", :method_name => "purge_timer", :zone => nil)
  end

  def task_purge_timer
    queue_work(:class_name => "MiqTask", :method_name => "purge_timer", :zone => nil)
  end

  def policy_event_purge_timer
    queue_work(:class_name => "PolicyEvent", :method_name => "purge_timer", :zone => nil)
  end

  def compliance_purge_timer
    queue_work(:class_name => "Compliance", :method_name => "purge_timer", :zone => nil)
  end

  def miq_report_result_purge_timer
    queue_work(:class_name => "MiqReportResult", :method_name => "purge_timer", :zone => nil)
  end

  def archived_entities_purge_timer
    queue_work(:class_name => "Container", :method_name => "purge_timer", :zone => nil)
    queue_work(:class_name => "ContainerNode", :method_name => "purge_timer", :zone => nil)
    queue_work(:class_name => "ContainerGroup", :method_name => "purge_timer", :zone => nil)
    queue_work(:class_name => "ContainerImage", :method_name => "purge_timer", :zone => nil)
    queue_work(:class_name => "ContainerProject", :method_name => "purge_timer", :zone => nil)
    queue_work(:class_name => "ContainerQuota", :method_name => "purge_timer", :zone => nil)
    queue_work(:class_name => "ContainerQuotaItem", :method_name => "purge_timer", :zone => nil)
  end

  def binary_blob_purge_timer
    queue_work(:class_name => "BinaryBlob", :method_name => "purge_timer", :zone => nil)
  end

  def vim_performance_states_purge_timer
    queue_work(:class_name => "VimPerformanceState", :method_name => "purge_timer", :zone => nil)
  end

  def miq_schedule_queue_scheduled_work(schedule_id, rufus_job)
    MiqSchedule.queue_scheduled_work(schedule_id, rufus_job.job_id, rufus_job.next_time.to_i, rufus_job.opts)
  end

  def database_maintenance_reindex_timer
    ::Settings.database.maintenance.reindex_tables.each do |class_name|
      queue_work(:class_name => class_name, :method_name => "reindex", :role => "database_operations", :zone => nil)
    end
  end

  def database_maintenance_vacuum_timer
    ::Settings.database.maintenance.vacuum_tables.each do |class_name|
      queue_work(:class_name => class_name, :method_name => "vacuum", :role => "database_operations", :zone => nil)
    end
  end

  def queue_miq_queue_check_for_timeout
    queue_work(:class_name => "MiqQueue", :method_name => "check_for_timeout", :zone => nil)
  end

  def check_for_stuck_vm_scan_dispatch(threshold_seconds)
    class_n = "VmScan::Dispatcher"
    method_n = "dispatch"
    Zone.in_my_region.each do |z|
      zone = z.name
      threshold = threshold_seconds.seconds.ago.utc
      MiqQueue
        .in_my_region
        .includes(:handler)
        .where(:class_name => class_n, :method_name => method_n, :state => 'dequeue', :zone => zone)
        .where("updated_on < ?", threshold)
        .each do |msg|
          if msg.handler.respond_to?(:is_current?) && msg.handler.is_current?
            msg.check_for_timeout("MIQ(MiqQueue.check_for_timeout)", 10.seconds, threshold_seconds * 3)
          else
            msg.check_for_timeout("MIQ(MiqQueue.check_for_timeout)", 10.seconds, threshold_seconds)
          end
        end
    end
  end

  def generate_chargeback_for_service(args = {})
    queue_work(:class_name => "Service", :method_name => "queue_chargeback_reports", :zone => nil, :args => args)
  end

  def check_for_timed_out_active_tasks
    queue_work(:class_name => "MiqTask", :method_name => "update_status_for_timed_out_active_tasks", :zone => nil)
  end

  private

  def queue_work(options)
    return if options.nil?

    options = {:zone => MiqServer.my_zone, :priority => MiqQueue::MEDIUM_PRIORITY}.merge(options)
    # always has class_name, method_name, zone, priority [often has role]
    MiqQueue.put_unless_exists(options)
  end

  def queue_work_on_each_zone(options)
    Zone.in_my_region.each { |z| queue_work(options.merge(:zone => z.name)) }
  end

  def queue_work_on_each_zone_with_active_role(role_name, options)
    Zone.in_my_region
        .with_active_role(role_name)
        .each { |z| queue_work(options.merge(:zone => z.name)) }
  end
end
