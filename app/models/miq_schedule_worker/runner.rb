class MiqScheduleWorker::Runner < MiqWorker::Runner
  include ActiveSupport::Callbacks
  define_callbacks(:dst_change)
  set_callback(:dst_change, :after, :load_user_schedules)

  ROLES_NEEDING_RESTART = ["scheduler", "ems_metrics_coordinator", "event"]
  CLASS_TAG = "MiqSchedule"

  def after_initialize
    @queue            = Queue.new    # Global Work Queue
    @schedules        = {}
    initialize_rufus
  end

  def initialize_rufus
    require 'rufus/scheduler'
    @system_scheduler = Rufus::Scheduler.new
    @user_scheduler   = Rufus::Scheduler.new
  end

  def dst?
    Time.now.dst?
  end

  def check_dst
    return if @dst == dst?

    run_callbacks(:dst_change) do
      reset_dst
    end
  end

  def reset_dst
    @dst = dst?
  end

  def queue_length
    @queue.length
  end

  def enqueue(object)
    @queue.enq(object)
  end

  def load_system_schedules
    schedules_for_all_roles
    schedules_for_scheduler_role
    schedules_for_database_operations_role
    schedules_for_ems_metrics_coordinator_role
    schedules_for_event_role
  end

  def load_user_schedules
    sync_all_user_schedules if schedule_enabled?(:scheduler)
  end

  def schedule_enabled?(role)
    role == :all || @active_roles.include?(role.to_s)
  end

  def scheduler_for(role)
    @schedules[role] ||= []
    ::MiqScheduleWorker::Scheduler.new(_log, @schedules[role], @system_scheduler)
  end

  def schedules_for_all_roles
    # These schedules need to be run on all servers regardless of the server's role
    scheduler = scheduler_for(:all)
    schedule_category = :schedules_for_all_roles

    # Schedule - Log current system configuration
    scheduler.schedule_every(
      :vmdb_appliance_log_config,
      worker_settings[:log_active_configuration_interval],
      :tags => [:vmdb_appliance_log_config, schedule_category]
    ) do
      enqueue(:vmdb_appliance_log_config)
    end

    # Schedule - Update Server Statistics
    scheduler.schedule_every(
      :miq_server_status_update,
      worker_settings[:server_stats_interval],
      :tags => [:status_update, schedule_category]
    ) do
      enqueue(:miq_server_status_update)
    end

    # Schedule - Log Server and Worker Statistics
    scheduler.schedule_every(
      :miq_server_worker_log_status,
      worker_settings[:server_log_stats_interval],
      :tags => [:log_status, schedule_category]
    ) do
      enqueue(:miq_server_worker_log_status)
    end

    # Schedule - Periodic logging of database statistics
    scheduler.schedule_every(
      :vmdb_database_connection_log_statistics,
      worker_settings[:db_diagnostics_interval],
      :first_in => 1.minute,
      :tags     => [:log_statistics, schedule_category]
    ) do
      enqueue(:vmdb_database_connection_log_statistics)
    end

    # Schedule - Add audit log entry for total number of vms managed by system.
    scheduler.schedule_every(
      :miq_server_audit_managed_resources,
      worker_settings[:audit_managed_resources],
      :tags => [:miq_server_audit_managed_resources, schedule_category]
    ) do
      enqueue(:miq_server_audit_managed_resources)
    end

    @schedules[:all]
  end

  def schedules_for_scheduler_role
    # These schedules need to run only once in a region per interval, so let the single scheduler role handle them
    return unless schedule_enabled?(:scheduler)

    scheduler = scheduler_for(:scheduler)

    # Schedule - Check for timed out jobs
    scheduler.schedule_every(
      :job_check_jobs_for_timeout,
      worker_settings[:job_timeout_interval]
    ) do
      enqueue(:job_check_jobs_for_timeout)
    end

    # Schedule - Check for retired items and start retirement
    # TODO: remove redundant settings in follow-up pr
    retirement_minimum_interval = [worker_settings[:service_retired_interval], worker_settings[:vm_retired_interval], worker_settings[:orchestration_stack_retired_interval]].min
    scheduler.schedule_every(
      :retirement_check,
      retirement_minimum_interval
    ) do
      enqueue(:retirement_check)
    end

    # Schedule - Periodic validation of authentications
    scheduler.schedule_every(
      :authentication_check_schedule,
      worker_settings[:authentication_check_interval]
    ) do
      # Queue authentication checks for CIs with credentials
      enqueue(:host_authentication_check_schedule)
      enqueue(:ems_authentication_check_schedule)
    end

    # Schedule - Check for session timeouts
    # NOTE: Session is global to the region, therefore, run it only once on the scheduler's server
    if Session.enabled?
      scheduler.schedule_every(
        :session_check_session_timeout,
        worker_settings[:session_timeout_interval]
      ) do
        enqueue(:session_check_session_timeout)
      end
    end

    # Schedule - Check for rogue EVM snapshots
    job_not_found_delay = worker_settings[:evm_snapshot_delete_delay_for_job_not_found]
    scheduler.schedule_every(
      :job_check_for_evm_snapshots,
      worker_settings[:evm_snapshot_interval]
    ) do
      enqueue([:job_check_for_evm_snapshots, job_not_found_delay])
    end

    # Schedule - ManageIQ::Providers::Kubernetes::ContainerManager::Scanning::Job::Dispatcher
    # Queue a ContainerManager::Scanning::Job::Dispatcher task unless there's already one on the queue
    scheduler.schedule_every(:container_scan_dispatcher_dispatch, worker_settings[:container_scan_dispatcher_interval]) do
      enqueue(:container_scan_dispatcher_dispatch)
    end

    # Schedule - VmScan::Dispatcher
    # Queue a VmScan::Dispatcher task unless there's already one on the queue
    scheduler.schedule_every(:vm_scan_dispatcher_dispatch, worker_settings[:vm_scan_dispatcher_interval]) do
      enqueue(:vm_scan_dispatcher_dispatch)
    end

    # Schedule - ManageIQ::Providers::ImageImportJob::Dispatcher
    # Queue a ManageIQ::Providers::ImageImportJob::Dispatcher task unless there's already one on the queue
    scheduler.schedule_every(:image_import_dispatcher_dispatch, worker_settings[:image_import_dispatcher_interval]) do
      enqueue(:image_import_dispatcher_dispatch)
    end

    # Schedule - Check for a stuck VmScan::Dispatcher#dispatch
    stuck_vm_scan_dispatch_threshold = worker_settings[:vm_scan_dispatcher_stale_message_timeout]
    scheduler.schedule_every(
      :check_for_stuck_dispatch,
      worker_settings[:vm_scan_dispatcher_stale_message_check_interval]
    ) do
      enqueue([:check_for_stuck_vm_scan_dispatch, stuck_vm_scan_dispatch_threshold])
    end

    # Schedule - Hourly Alert Evaluation Timer
    scheduler.schedule_every(
      :miq_alert_evaluate_hourly_timer,
      1.hour,
      :first_in => 5.minutes
    ) do
      enqueue(:miq_alert_evaluate_hourly_timer)
    end

    # Schedule - Purging of drift states
    scheduler.schedule_every(
      :drift_state_purge_timer,
      worker_settings[:drift_state_purge_interval]
    ) do
      enqueue(:drift_state_purge_timer)
    end

    # Schedule - Purging of reports
    scheduler.schedule_every(
      :miq_report_result_purge_timer,
      worker_settings[:report_result_purge_interval]
    ) do
      enqueue(:miq_report_result_purge_timer)
    end

    # Schedule - Purging of archived entities
    scheduler.schedule_every(
      :archived_entities_purge_timer,
      worker_settings[:container_entities_purge_interval]
    ) do
      enqueue(:archived_entities_purge_timer)
    end

    # Schedule - Purging of binary blobs
    scheduler.schedule_every(
      :binary_blob_purge_timer,
      worker_settings[:binary_blob_purge_interval]
    ) do
      enqueue(:binary_blob_purge_timer)
    end

    # Schedule - Purging of audit events
    scheduler.schedule_every(
      :audit_event_purge_timer,
      worker_settings[:audit_events_purge_interval]
    ) do
      enqueue(:audit_event_purge_timer)
    end

    # Schedule - Purging of notifications
    scheduler.schedule_every(
      :notification_purge_timer,
      worker_settings[:notifications_purge_interval]
    ) do
      enqueue(:notification_purge_timer)
    end

    # Schedule - Purging of tasks
    scheduler.schedule_every(
      :task_purge_timer,
      worker_settings[:task_purge_interval]
    ) do
      enqueue(:task_purge_timer)
    end

    # Schedule - Purging of compliances
    scheduler.schedule_every(
      :compliance_purge_timer,
      worker_settings[:compliance_purge_interval]
    ) do
      enqueue(:compliance_purge_timer)
    end

    # Schedule - Purging of vim performance states
    scheduler.schedule_every(
      :vim_performance_states_purge_timer,
      worker_settings[:vim_performance_states_purge_interval]
    ) do
      enqueue(:vim_performance_states_purge_timer)
    end

    # Schedule - Check for timed out queue messages
    scheduler.schedule_every(
      :queue_miq_queue_check_for_timeout,
      worker_settings[:queue_timeout_interval]
    ) do
      enqueue(:queue_miq_queue_check_for_timeout)
    end

    # Schedule - Storage smartstate scanning
    at = worker_settings[:storage_file_collection_time_utc]
    time_at = if Time.zone.today.to_time(:utc) + at.seconds < Time.now.utc
                Time.zone.today.to_time(:utc) + at.seconds + 1.day
              else
                Time.zone.today.to_time(:utc) + at.seconds
              end
    scheduler.schedule_every(
      :storage_scan_timer,
      worker_settings[:storage_file_collection_interval],
      :first_at => time_at
    ) do
      enqueue(:storage_scan_timer)
    end

    # Schedule - Full EMS refresh
    # NOTE: There is one schedule created per supported class
    schedule_settings_for_ems_refresh.each do |klass, local_every|
      scheduler.schedule_every(
        "ems_refresh_timer (#{klass.name})",
        local_every
      ) do
        enqueue([:ems_refresh_timer, klass])
      end
    end

    schedule_chargeback_report_for_service_daily

    schedule_check_for_task_timeout

    @schedules[:scheduler]
  end

  def schedule_check_for_task_timeout
    # Schedule - Check for active tasks that have timed out
    every = worker_settings[:task_timeout_check_frequency]
    scheduler = scheduler_for(:scheduler)
    scheduler.schedule_every(
      :check_for_timed_out_active_tasks,
      every,
      :first_at => 1.minute.from_now
    ) do
      enqueue(:check_for_timed_out_active_tasks)
    end
  end

  def schedule_chargeback_report_for_service_daily
    # Schedule - Chargeback generation
    every = worker_settings[:chargeback_generation_interval]
    at = worker_settings[:chargeback_generation_time_utc]
    time_at = Time.current.strftime("%Y-%m-%d #{at}").to_time(:utc)
    time_at += 1.day if time_at < 1.hour.from_now
    scheduler = scheduler_for(:scheduler)
    scheduler.schedule_every(
      :generate_chargeback_for_service,
      every,
      :first_at => time_at
    ) do
      enqueue([:generate_chargeback_for_service, {:report_source => "Daily scheduler"}])
    end
  end

  def schedules_for_database_operations_role
    return unless schedule_enabled?(:database_operations)

    scheduler = scheduler_for(:database_operations)

    # Schedule - Database reindexing
    scheduler.schedule_cron(
      :database_maintenance_reindex_timer,
      ::Settings.database.maintenance.reindex_schedule,
      :tags => %i[database_operations database_maintenance_reindex_schedule]
    ) do
      enqueue(:database_maintenance_reindex_timer)
    end

    # Schedule - Database vacuuming
    scheduler.schedule_cron(
      :database_maintenance_vacuum_timer,
      ::Settings.database.maintenance.vacuum_schedule,
      :tags => %i[database_operations database_maintenance_vacuum_schedule]
    ) do
      enqueue(:database_maintenance_vacuum_timer)
    end

    # Schedule - Purge realtime metrics
    scheduler.schedule_every(
      :metric_purging_purge_realtime_timer,
      worker_settings[:performance_realtime_purging_interval],
      :first_in => worker_settings[:performance_realtime_purging_start_delay],
      :tags     => [:database_operations, :purge_realtime_timer]
    ) do
      enqueue(:metric_purging_purge_realtime_timer)
    end

    # Schedule - Purge rollup metrics
    scheduler.schedule_every(
      :metric_purging_purge_rollup_timer,
      worker_settings[:performance_rollup_purging_interval],
      :first_in => worker_settings[:performance_rollup_purging_start_delay],
      :tags     => [:database_operations, :purge_rollup_timer]
    ) do
      enqueue(:metric_purging_purge_rollup_timer)
    end

    @schedules[:database_operations]
  end

  def schedules_for_ems_metrics_coordinator_role
    return unless schedule_enabled?("ems_metrics_coordinator")

    scheduler = scheduler_for(:ems_metrics_coordinator)

    # Schedule - Performance Collection
    scheduler.schedule_every(
      :metric_capture_perf_capture_timer,
      worker_settings[:performance_collection_interval],
      :first_in => worker_settings[:performance_collection_start_delay],
      :tags     => [:ems_metrics_coordinator, :perf_capture_timer]
    ) do
      enqueue(:metric_capture_perf_capture_timer)
    end

    @schedules[:ems_metrics_coordinator]
  end

  def schedules_for_event_role
    # These schedules need to run by the servers with the event role
    return unless schedule_enabled?(:event)

    scheduler = scheduler_for(:event)

    # Schedule - Purging of event streams
    scheduler.schedule_every(
      :event_stream_purge_timer,
      worker_settings[:event_streams_purge_interval],
      :first_in => 5.minutes,
      :tags     => [:event_stream, :purge_schedule]
    ) do
      enqueue(:event_stream_purge_timer)
    end

    # Schedule - Purging of policy events
    scheduler.schedule_every(
      :policy_event_purge_timer,
      worker_settings[:policy_events_purge_interval],
      :first_in => 5.minutes,
      :tags     => [:policy_event, :purge_schedule]
    ) do
      enqueue(:policy_event_purge_timer)
    end

    @schedules[:event]
  end

  def sync_all_user_schedules
    rufus_remove_stale_schedules
    schedules = MiqSchedule.in_my_region.to_a
    @last_checked = Time.now.utc
    reload_schedules(schedules)
  end

  def sync_updated_user_schedules
    rufus_remove_stale_schedules
    threshold = @last_checked || Time.at(0)
    schedules = MiqSchedule.in_my_region.updated_since(threshold)
    @last_checked = Time.now.utc
    reload_schedules(schedules)
  end

  def reload_schedules(schedules)
    schedules.each do |sch|
      _log.info("Reloading schedule: [#{sch.name}] with id: [#{sch.id}]")
      rufus_remove_schedules_by_tag(sch.tag)
      rufus_add_schedule(sch.rufus_schedule_opts) if sch.enabled == true
    end
    schedules
  end

  # rufus_add_schedule(:method => :schedule_every, :interval => int, :schedule_id => self.id, :first_at => time, :tags => self.tag)
  # rufus_add_schedule(:method => :schedule_at, :interval => time, :schedule_id => self.id, :discard_past => true, :tags => self.tag)
  # rufus_add_schedule(:method => :schedule_at, :interval => time, :months => 1, :schedule_id => self.id, :discard_past => true, :tags => self.tag
  def rufus_add_schedule(options = {})
    return if options.blank?
    unless @user_scheduler.respond_to?(options[:method])
      raise _("invalid method: %{options}") % {:options => options[:method]}
    end

    Array.wrap(options[:tags]) << CLASS_TAG
    @schedules[:scheduler] ||= []
    if options[:months]
      rufus_add_monthly_schedule(options)
    else
      rufus_add_normal_schedule(options)
    end
  end

  def rufus_add_normal_schedule(options)
    method = options.delete(:method)
    interval = options.delete(:interval)
    schedule_id = options.delete(:schedule_id)
    options[:job] = true

    @schedules[:scheduler] << @user_scheduler.send(method, interval, options) do |rufus_job|
      enqueue([:miq_schedule_queue_scheduled_work, schedule_id, rufus_job])
    end
  end

  def rufus_add_monthly_schedule(options)
    months = options.delete(:months)
    method = options.delete(:method)
    options.delete(:interval)
    schedule_id = options.delete(:schedule_id)

    # Treat months differently since rufus doesn't support :schedule_every with X.months type of options
    sch = MiqSchedule.find(schedule_id)
    next_run = sch.next_interval_time
    @schedules[:scheduler] << @user_scheduler.send(method, next_run, options.dup) do |rufus_job|
      enqueue([:miq_schedule_queue_scheduled_work, schedule_id, rufus_job])
    end

    # Schedule every X months for up to 5 years in the future
    remaining_months = ((5 * 12) / months) - 1
    remaining_months.times do
      next_run += months.months
      @schedules[:scheduler] << @user_scheduler.send(method, next_run, options.dup) do |rufus_job|
        enqueue([:miq_schedule_queue_scheduled_work, schedule_id, rufus_job])
      end
    end
    @schedules[:scheduler]
  end

  def rufus_remove_stale_schedules
    active_tags = MiqSchedule.in_zone(MiqServer.my_zone).collect(&:tag)
    @user_scheduler.jobs(:tag => CLASS_TAG).each do |rufus_job|
      if (active_tags & rufus_job.tags).empty?
        _log.info("Unscheduling Tag: #{rufus_job.tags.inspect}")
        rufus_job.unschedule
      end
    end
  end

  def rufus_remove_schedules_by_tag(tag)
    rufus_jobs = @user_scheduler.jobs(:tag => tag)
    _log.info("Unscheduling #{rufus_jobs.length} jobs with tag: #{tag}") unless rufus_jobs.empty?
    rufus_jobs.each(&:unschedule)
  end

  def after_sync_active_roles
    check_roles_changed unless @current_roles.nil?
  end

  BRUTE_FORCE = false
  def check_roles_changed
    added   = @active_roles - @current_roles
    removed = @current_roles - @active_roles

    if BRUTE_FORCE
      restart = ROLES_NEEDING_RESTART & (added + removed)
      unless restart.empty?
        msg = restart.sort.collect { |r| "#{r} role #{added.include?(r) ? "added" : "removed"}" }.join(', ')
        do_exit("#{msg}. Restarting.", 1)
      end
    else
      begin
        added.each do |r|
          m = "schedules_for_#{r}_role"
          next unless respond_to?(m)

          _log.info("Adding Schedules for Role=[#{r}]")
          send(m)
        end

        load_user_schedules if added.include?("scheduler")

        removed.each do |r|
          rs = r.to_sym
          next unless @schedules.key?(rs)

          _log.info("Removing Schedules for Role=[#{r}]")
          @schedules[rs].each do |j|
            # In Rufus::Scheduler Version 1, schedule returns a JobID
            # In Rufus::Scheduler Version 2, schedule returns a Job
            # In Rufus::Scheduler Version 3, schedule could return a Job/JobID, depending on whether :job => true is
            # passed to opts
            if j.kind_of?(Integer)
              @system_scheduler.unschedule(j)
            else
              if j.respond_to?(:tags)
                if j.tags.any? { |t| t.to_s.starts_with?("miq_schedules_") }
                  _log.info("Removing user schedule with Tags: #{j.tags.inspect}")
                end
                j.unschedule
              end
            end
          end
          @schedules.delete(rs)
        end
      rescue Exception => err
        msg = "Error adjusting schedules: #{err.message}"
        _log.error(msg)
        _log.log_backtrace(err)
        do_exit("#{msg}. Restarting.", 1)
      end
    end

    _log.info("Roles added: #{added.inspect}, Roles removed: #{removed.inspect}") unless added.empty? && removed.empty?
    @current_roles = @active_roles.dup
  end

  def do_before_work_loop
    @current_roles = @active_roles.dup
    load_system_schedules
    load_user_schedules
    reset_dst
  end

  def do_work
    schedule_worker_jobs = MiqScheduleWorker::Jobs.new
    while @queue.length > 0
      heartbeat
      method_to_send, *args = @queue.deq
      begin
        schedule_worker_jobs.public_send(method_to_send, *args)
      rescue ActiveRecord::StatementInvalid, SystemExit
        raise
      rescue Exception => err
        _log.error(err.message)
        _log.log_backtrace(err)
      end
      Thread.pass
    end

    check_dst

    # If no work in queue, update users schedules which have been updated since last check
    sync_updated_user_schedules if schedule_enabled?(:scheduler)
  end

  private

  # @returns Hash<class, Integer> Hash of ems_class => refresh_interval
  def schedule_settings_for_ems_refresh
    ExtManagementSystem.permitted_subclasses.each.with_object({}) do |klass, hash|
      next if klass.ems_type.nil? || !klass.supports?(:refresh_ems)

      every = ::Settings.ems_refresh[klass.ems_type].try(:refresh_interval) || ::Settings.ems_refresh.refresh_interval
      every = every.respond_to?(:to_i_with_method) ? every.to_i_with_method : every.to_i
      hash[klass] = every unless every == 0
    end
  end
end
