require 'thread'

class MiqScheduleWorker::Runner < MiqWorker::Runner
  include ActiveSupport::Callbacks
  define_callbacks(:dst_change)
  set_callback(:dst_change, :after, :load_user_schedules)

  OPTIONS_PARSER_SETTINGS = MiqWorker::Runner::OPTIONS_PARSER_SETTINGS + [
    [:emsid, 'EMS Instance ID', String],
  ]

  ROLES_NEEDING_RESTART = ["scheduler", "ems_metrics_coordinator", "event"]
  SCHEDULE_MEDIUM_PRIORITY = MiqQueue.priority(:normal, :higher, 10)
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
    ::MiqScheduleWorker::Scheduler.new(self._log, @schedules[role], @system_scheduler)
  end

  def schedules_for_all_roles
    # These schedules need to be run on all servers regardless of the server's role
    scheduler = scheduler_for(:all)
    schedule_category = :schedules_for_all_roles

    # Schedule - Log current system configuration
    every = worker_settings[:log_active_configuration_interval]

    scheduler.schedule_every(every, :tags => [:vmdb_appliance_log_config, schedule_category]) do
      enqueue(:vmdb_appliance_log_config)
    end

    # Schedule - Log current database statistics and bloat
    every = worker_settings[:log_database_statistics_interval]
    scheduler.schedule_every(every, :tags => [:log_all_database_statistics, schedule_category]) do
      enqueue(:vmdb_database_log_all_database_statistics)
    end

    # Schedule - Update Server Statistics
    every = worker_settings[:server_stats_interval]
    scheduler.schedule_every(
      every,
      :first_in => every,
      :tags     => [:status_update, schedule_category]
    ) { enqueue(:miq_server_status_update) }

    # Schedule - Log Server and Worker Statistics
    every = worker_settings[:server_log_stats_interval]
    scheduler.schedule_every(
      every,
      :first_in => every,
      :tags     => [:log_status, schedule_category]
    ) { enqueue(:miq_server_worker_log_status) }

    # Schedule - Periodic logging of database statistics
    interval = worker_settings[:db_diagnostics_interval]
    scheduler.schedule_every(
      interval,
      :first_in => 1.minute,
      :tags     => [:log_statistics, schedule_category]
    ) { enqueue(:vmdb_database_connection_log_statistics) }

    # Schedule - Periodic check for updates on appliances only
    if MiqEnvironment::Command.is_appliance?
      interval = worker_settings[:yum_update_check]
      scheduler.schedule_every(
        interval,
        :first_in => 1.minute,
        :tags     => [:server_updates, schedule_category]
      ) { enqueue(:miq_server_queue_update_registration_status) }
    end

    @schedules[:all]
  end

  def schedules_for_scheduler_role
    # These schedules need to run only once in a zone per interval, so let the single scheduler role handle them
    return unless schedule_enabled?(:scheduler)
    scheduler = scheduler_for(:scheduler)
    # Schedule - Check for timed out jobs
    every = worker_settings[:job_timeout_interval]
    scheduler.schedule_every(every, :first_in => every) do
      enqueue(:job_check_jobs_for_timeout)
    end

    # Schedule - Check for retired items and start retirement
    # TODO: remove redundant settings in follow-up pr
    every = [worker_settings[:service_retired_interval], worker_settings[:vm_retired_interval], worker_settings[:orchestration_stack_retired_interval], worker_settings[:load_balancer_retired_interval]].min
    scheduler.schedule_every(every, :first_in => every) do
      enqueue(:retirement_check)
    end

    # Schedule - Periodic validation of authentications
    every = worker_settings[:authentication_check_interval]
    scheduler.schedule_every(every, :first_in => every) do
      # Queue authentication checks for CIs with credentials
      enqueue(:host_authentication_check_schedule)
      enqueue(:ems_authentication_check_schedule)
    end

    every = worker_settings[:drift_state_purge_interval]
    scheduler.schedule_every(every, :first_in => every) do
      enqueue(:drift_state_purge_timer)
    end

    if Session.enabled?
      # Schedule - Check for session timeouts
      scheduler.schedule_every(worker_settings[:session_timeout_interval]) do
        # Session is global to the region, therefore, run it only once on the scheduler's server
        enqueue(:session_check_session_timeout)
      end
    end

    # Schedule - Check for rogue EVM snapshots
    every               = worker_settings[:evm_snapshot_interval]
    job_not_found_delay = worker_settings[:evm_snapshot_delete_delay_for_job_not_found]
    scheduler.schedule_every(every, :first_in => every) do
      enqueue([:job_check_for_evm_snapshots, job_not_found_delay])
    end

    # Queue a JobProxyDispatcher dispatch task at high priority unless there's already one on the queue
    # This dispatch method goes through all pending jobs to see if there's a free proxy available to work on one of them
    # It is very expensive to constantly do this, hence the need to ensure only one is on the queue at one time
    scheduler.schedule_every(worker_settings[:job_proxy_dispatcher_interval]) do
      enqueue(:job_proxy_dispatcher_dispatch)
    end

    stale_interval = worker_settings[:job_proxy_dispatcher_stale_message_check_interval]
    threshold_seconds = worker_settings[:job_proxy_dispatcher_stale_message_timeout]
    scheduler.schedule_every(stale_interval) do
      enqueue([:check_for_stuck_dispatch, threshold_seconds])
    end

    # Schedule - Hourly Alert Evaluation Timer
    scheduler.schedule_every(1.hour, :first_in => 5.minutes) do
      enqueue(:miq_alert_evaluate_hourly_timer)
    end

    # Schedule - Prune old reports Timer
    every = worker_settings[:report_result_purge_interval]
    scheduler.schedule_every(every, :first_in => every) do
      enqueue(:miq_report_result_purge_timer)
    end

    every = worker_settings[:container_entities_purge_interval]
    scheduler.schedule_every(every, :first_in => every) do
      enqueue(:archived_entities_purge_timer)
    end

    every = worker_settings[:binary_blob_purge_interval]
    scheduler.schedule_every(every, :first_in => every) do
      enqueue(:binary_blob_purge_timer)
    end

    every = worker_settings[:vim_performance_states_purge_interval]
    scheduler.schedule_every(every, :first_in => every) do
      enqueue(:vim_performance_states_purge_timer)
    end

    # Schedule every 24 hours
    at = worker_settings[:storage_file_collection_time_utc]
    if Time.now.strftime("%Y-%m-%d #{at}").to_time(:utc) < Time.now.utc
      time_at = 1.day.from_now.utc.strftime("%Y-%m-%d #{at}").to_time(:utc)
    else
      time_at = Time.now.strftime("%Y-%m-%d #{at}").to_time(:utc)
    end
    scheduler.schedule_every(
      worker_settings[:storage_file_collection_interval],
      :first_at => time_at
    ) { enqueue(:storage_scan_timer) }

    schedule_settings_for_ems_refresh.each do |klass, every|
      scheduler.schedule_every(every, :first_in => every) do
        enqueue([:ems_refresh_timer, klass])
      end
    end

    # run chargeback generation every day at specific time
    schedule_chargeback_report_for_service_daily

    schedule_check_for_task_timeout

    @schedules[:scheduler]
  end

  def schedule_check_for_task_timeout
    every = worker_settings[:task_timeout_check_frequency]
    scheduler = scheduler_for(:scheduler)
    scheduler.schedule_every(every, :first_at => Time.current + 1.minute) do
      enqueue(:check_for_timed_out_active_tasks)
    end
  end

  def schedule_chargeback_report_for_service_daily
    every = worker_settings[:chargeback_generation_interval]
    at = worker_settings[:chargeback_generation_time_utc]
    time_at = Time.current.strftime("%Y-%m-%d #{at}").to_time(:utc)
    time_at += 1.day if time_at < Time.current + 1.hour
    scheduler = scheduler_for(:scheduler)
    scheduler.schedule_every(every, :first_at => time_at) do
      enqueue([:generate_chargeback_for_service, :report_source => "Daily scheduler"])
    end
  end

  def schedules_for_database_operations_role
    # Schedule - Database Metrics capture run by the appliance with a database_operations role
    return unless schedule_enabled?(:database_operations)
    scheduler = scheduler_for(:database_operations)

    sched = ::Settings.database.metrics_collection.collection_schedule
    _log.info("database_metrics_collection_schedule: #{sched}")
    scheduler.schedule_cron(
      sched,
      :tags => [:database_operations, :database_metrics_collection_schedule],
    ) { enqueue(:vmdb_database_capture_metrics_timer) }

    sched = ::Settings.database.metrics_collection.daily_rollup_schedule
    _log.info("database_metrics_daily_rollup_schedule: #{sched}")
    scheduler.schedule_cron(
      sched,
      :tags => [:database_operations, :database_metrics_daily_rollup_schedule],
    ) { enqueue(:vmdb_database_rollup_metrics_timer) }

    sched = ::Settings.database.metrics_history.purge_schedule
    _log.info("database_metrics_purge_schedule: #{sched}")
    scheduler.schedule_cron(
      sched,
      :tags => [:database_operations, :database_metrics_purge_schedule],
    ) { enqueue(:metric_purge_all_timer) }

    sched = ::Settings.database.maintenance.reindex_schedule
    _log.info("database_maintenance_reindex_schedule: #{sched}")
    scheduler.schedule_cron(
      sched,
      :tags => %i(database_operations database_maintenance_reindex_schedule),
    ) { enqueue(:database_maintenance_reindex_timer) }

    sched = ::Settings.database.maintenance.vacuum_schedule
    _log.info("database_maintenance_vacuum_schedule: #{sched}")
    scheduler.schedule_cron(
      sched,
      :tags => %i(database_operations database_maintenance_vacuum_schedule),
    ) { enqueue(:database_maintenance_vacuum_timer) }

    @schedules[:database_operations]
  end

  def schedules_for_ems_metrics_coordinator_role
    # These schedules need to run by the servers with the coordinator role
    return unless schedule_enabled?("ems_metrics_coordinator")
    scheduler = scheduler_for(:ems_metrics_coordinator)
    # Schedule - Performance Collection and Performance Purging
    every    = worker_settings[:performance_collection_interval]
    first_in = worker_settings[:performance_collection_start_delay]
    scheduler.schedule_every(
      every,
      :first_in => first_in,
      :tags     => [:ems_metrics_coordinator, :perf_capture_timer]
    ) { enqueue(:metric_capture_perf_capture_timer) }

    every    = worker_settings[:performance_realtime_purging_interval]
    first_in = worker_settings[:performance_realtime_purging_start_delay]
    scheduler.schedule_every(
      every,
      :first_in => first_in,
      :tags     => [:ems_metrics_coordinator, :purge_realtime_timer]
    ) { enqueue(:metric_purging_purge_realtime_timer) }

    every    = worker_settings[:performance_rollup_purging_interval]
    first_in = worker_settings[:performance_rollup_purging_start_delay]
    scheduler.schedule_every(
      every,
      :first_in => first_in,
      :tags     => [:ems_metrics_coordinator, :purge_rollup_timer]
    ) { enqueue(:metric_purging_purge_rollup_timer) }

    @schedules[:ems_metrics_coordinator]
  end

  def schedules_for_event_role
    # These schedules need to run by the servers with the event role
    return unless schedule_enabled?(:event)
    scheduler = scheduler_for(:event)
    # Schedule - Event Purging
    interval = worker_settings[:event_streams_purge_interval]
    scheduler.schedule_every(
      interval,
      :first_in => "300s",
      :tags     => [:event_stream, :purge_schedule]
    ) { enqueue(:event_stream_purge_timer) }

    # Schedule - Policy Event Purging
    interval = worker_settings[:policy_events_purge_interval]
    scheduler.schedule_every(
      interval,
      :first_in => "300s",
      :tags     => [:policy_event, :purge_schedule]
    ) { enqueue(:policy_event_purge_timer) }

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
    schedules = MiqSchedule.updated_since(threshold)
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

    options[:tags].to_miq_a << CLASS_TAG
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
          next unless self.respond_to?(m)
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
    _log.info("Number of scheduled items to be processed: #{queue_length}.")

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

  def schedule_settings_for_ems_refresh
    ExtManagementSystem.leaf_subclasses.each.with_object({}) do |klass, hash|
      next unless klass.ems_type
      every = ::Settings.ems_refresh[klass.ems_type].try(:refresh_interval) || ::Settings.ems_refresh.refresh_interval
      every = every.respond_to?(:to_i_with_method) ? every.to_i_with_method : every.to_i
      hash[klass] = every unless every == 0
    end
  end
end
