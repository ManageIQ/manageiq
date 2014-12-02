class ScheduleWorker < WorkerBase
  class Jobs
    def vmdb_appliance_log_config
      queue_work(:class_name  => "Vmdb::Appliance", :method_name => "log_config", :server_guid => MiqServer.my_guid)
    end

    def vmdb_database_log_all_database_statistics
      queue_work(:class_name  => "VmdbDatabase", :method_name => "log_all_database_statistics", :server_guid => MiqServer.my_guid)
    end

    def miq_server_status_update
      queue_work(:class_name  => "MiqServer", :method_name => "status_update", :server_guid => MiqServer.my_guid, :priority => MiqQueue::HIGH_PRIORITY)
    end

    def miq_server_worker_log_status
      queue_work(:class_name  => "MiqServer", :method_name => "log_status",     :task_id => "log_status", :server_guid => MiqServer.my_guid, :priority => MiqQueue::HIGH_PRIORITY)
      queue_work(:class_name  => "MiqWorker", :method_name => "log_status_all", :task_id => "log_status", :server_guid => MiqServer.my_guid, :priority => MiqQueue::HIGH_PRIORITY)
    end

    def miq_db_config_log_statistics
      queue_work(:class_name  => "MiqDbConfig", :method_name => "log_statistics", :server_guid => MiqServer.my_guid)
    end

    def miq_server_queue_update_registration_status
      queue_work(:class_name  => "MiqServer", :method_name => "queue_update_registration_status", :server_guid => MiqServer.my_guid)
    end

    def miq_server_resync_rhn_mirror
      queue_work(:class_name  => "MiqServer", :instance_id => MiqServer.my_server.id, :method_name => "resync_rhn_mirror", :server_guid => MiqServer.my_guid, :msg_timeout => 60.minutes, :task_id => "resync_rhn_mirror")
    end

    def host_check_for_vms_to_scan
      queue_work_on_each_zone(:class_name  => "Host", :method_name => "check_for_vms_to_scan")
    end

    def job_check_jobs_for_timeout
      queue_work_on_each_zone(:class_name  => "Job", :method_name => "check_jobs_for_timeout")
    end

    def service_retirement_check
      queue_work_on_each_zone(:class_name  => "Service", :method_name => "retirement_check")
    end

    def vm_retirement_check
      queue_work_on_each_zone(:class_name  => "Vm", :method_name => "retirement_check")
    end

    def host_authentication_check_schedule
      queue_work_on_each_zone(:class_name  => "Host", :method_name => "authentication_check_schedule")
    end

    def ems_authentication_check_schedule
      queue_work_on_each_zone(:class_name  => "ExtManagementSystem", :method_name => "authentication_check_schedule")
    end

    def storage_authentication_check_schedule
      queue_work_on_each_zone(:class_name  => "StorageManager",      :method_name => "authentication_check_schedule")
    end

    def session_check_session_timeout
      queue_work(:class_name  => "Session", :method_name => "check_session_timeout", :server_guid => MiqServer.my_guid)
    end

    def job_check_for_evm_snapshots(job_not_found_delay)
      queue_work_on_each_zone(:class_name  => "Job", :method_name => "check_for_evm_snapshots", :args => [job_not_found_delay])
    end

    def job_proxy_dispatcher_dispatch
      queue_work_on_each_zone(:class_name  => "JobProxyDispatcher", :method_name => "dispatch", :task_id => "job_dispatcher", :priority => MiqQueue::HIGH_PRIORITY, :role => "smartstate", :state => "ready")
    end

    def ems_refresh_all_ems_timer
      queue_work_on_each_zone(:class_name  => "ExtManagementSystem", :method_name => "refresh_all_ems_timer")
    end

    def ems_refresh_all_scvmm_timer
      queue_work_on_each_zone(:class_name  => "EmsMicrosoft", :method_name => "refresh_all_ems_timer")
    end

    def miq_alert_evaluate_hourly_timer
      queue_work_on_each_zone(:class_name  => "MiqAlert", :method_name => "evaluate_hourly_timer")
    end

    def storage_scan_timer
      queue_work(:class_name  => "Storage", :method_name => "scan_timer")
    end

    def metric_capture_perf_capture_timer
      zone = MiqServer.my_server(true).zone
      if zone.role_active?("ems_metrics_coordinator")
        queue_work(
          :class_name  => "Metric::Capture",
          :method_name => "perf_capture_timer",
          :role        => "ems_metrics_coordinator",
          :priority    => MiqQueue::HIGH_PRIORITY,
          :state       => ["ready", "dequeue"]
        )
      end
    end

    def metric_purging_purge_realtime_timer
      zone = MiqServer.my_server(true).zone
      if zone.role_active?("ems_metrics_processor")
        queue_work(:class_name => "Metric::Purging", :method_name => "purge_realtime_timer")
      end
    end

    def metric_purging_purge_rollup_timer
      zone = MiqServer.my_server(true).zone
      if zone.role_active?("ems_metrics_processor")
        queue_work(:class_name => "Metric::Purging", :method_name => "purge_rollup_timer")
      end
    end

    def ems_event_purge_timer
      zone = MiqServer.my_server(true).zone
      if zone.role_active?("event")
        queue_work(:class_name => "EmsEvent", :method_name => "purge_timer")
      end
    end

    def policy_event_purge_timer
      zone = MiqServer.my_server(true).zone
      if zone.role_active?("event")
        queue_work(:class_name => "PolicyEvent", :method_name => "purge_timer")
      end
    end

    def storage_refresh_metrics
      queue_work(
        :class_name  => "StorageManager",
        :method_name => "refresh_metrics",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :state       => ["ready", "dequeue"]
      )
    end

    def storage_metrics_rollup_hourly
      queue_work(
        :class_name  => "StorageManager",
        :method_name => "metrics_rollup_hourly",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :state       => ["ready", "dequeue"]
      )
    end

    def storage_metrics_rollup_daily(time_profile_id)
      queue_work(
        :class_name   => "StorageManager",
        :method_name  => "metrics_rollup_daily",
        :priority     => MiqQueue::HIGH_PRIORITY,
        :state        => ["ready", "dequeue"],
        :args         => [time_profile_id]
      )
    end

    def miq_storage_metric_purge_all_timer
      queue_work(
        :queue_name   => "storage_metrics_collector",
        :class_name   => "MiqStorageMetric",
        :method_name  => "purge_all_timer",
        :priority     => MiqQueue::HIGH_PRIORITY,
        :state        => ["ready", "dequeue"]
      )
    end

    def storage_refresh_inventory
      queue_work(
        :class_name   => "StorageManager",
        :method_name  => "refresh_inventory",
        :priority     => MiqQueue::HIGH_PRIORITY,
        :state        => ["ready", "dequeue"]
      )
    end

    def miq_schedule_queue_scheduled_work(schedule_id, rufus_job)
      MiqSchedule.queue_scheduled_work(schedule_id, rufus_job.job_id, rufus_job.at, rufus_job.params)
    end

    def ldap_server_sync_data_from_timer
      queue_work(:class_name => "LdapServer", :method_name => "sync_data_from_timer")
    end

    def vmdb_database_capture_metrics_timer
      role = MiqRegion.my_region.role_active?("database_owner") ? "database_owner" : "database_operations"
      queue_work(:class_name => "VmdbDatabase", :method_name => "capture_metrics_timer", :role => role, :zone => nil)
    end

    def vmdb_database_rollup_metrics_timer
      role = MiqRegion.my_region.role_active?("database_owner") ? "database_owner" : "database_operations"
      queue_work(:class_name => "VmdbDatabase", :method_name => "rollup_metrics_timer", :role => role, :zone => nil)
    end

    def metric_purge_all_timer
      ["VmdbDatabaseMetric", "VmdbMetric"].each do |class_name|
        queue_work(:class_name  => class_name, :method_name => "purge_all_timer", :role => "database_operations", :zone => nil)
      end
    end

    def check_for_stuck_dispatch(threshold_seconds)
      class_n = "JobProxyDispatcher"
      method_n = "dispatch"
      Zone.in_my_region.all.each do |z|
        zone = z.name
        threshold = threshold_seconds.ago.utc
        msgs = MiqQueue.in_my_region.all(:include => :handler, :conditions => ["class_name = ? and method_name = ? and state = 'dequeue' and zone = ? and updated_on < ?", class_n, method_n, zone, threshold])
        msgs.each do |msg|
          if msg.handler.respond_to?(:is_current?) && msg.handler.is_current?
            msg.check_for_timeout("MIQ(MiqQueue.check_for_timeout)", 10.seconds, threshold_seconds * 3 )
          else
            msg.check_for_timeout("MIQ(MiqQueue.check_for_timeout)", 10.seconds, threshold_seconds)
          end
        end
      end
    end

    private

    def queue_work(options)
      return if options.nil?
      options = {:zone => MiqServer.my_zone, :priority => SCHEDULE_MEDIUM_PRIORITY}.merge(options)
      # always has class_name, method_name, zone, priority [often has role]
      MiqQueue.put_unless_exists(options)
    end

    def queue_work_on_each_zone(options)
      Zone.in_my_region.all.each {|z| queue_work(options.merge(:zone => z.name))}
    end
  end
end
