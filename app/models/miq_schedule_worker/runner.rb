require 'thread'

class MiqScheduleWorker::Runner < MiqWorker::Runner
  include ActiveSupport::Callbacks
  define_callbacks :dst_change
  set_callback :dst_change, :after, :load_user_schedules

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
    @queue.enq object
  end

  def load_system_schedules
    schedules_for_all_roles
    schedules_for_scheduler_role
    schedules_for_database_operations_role
    schedules_for_ems_metrics_coordinator_role
    schedules_for_event_role
    schedules_for_storage_metrics_coordinator_role
    schedules_for_ldap_synchronization_role
  end

  def load_user_schedules
    sync_all_user_schedules if schedule_enabled?(:scheduler)
  end

  def worker_setting_or_default(keys, default = nil)
    worker_settings.fetch_path(keys) || default
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
    every = worker_setting_or_default(:log_active_configuration_interval, 1.days)
    scheduler.schedule_every(every, :tags => [:vmdb_appliance_log_config, schedule_category]) do
      enqueue :vmdb_appliance_log_config
    end

    # Schedule - Log current database statistics and bloat
    every = worker_setting_or_default(:log_database_statistics_interval, 1.days)
    scheduler.schedule_every(every, :tags => [:log_all_database_statistics, schedule_category]) do
      enqueue :vmdb_database_log_all_database_statistics
    end

    # Schedule - Update Server Statistics
    every = worker_setting_or_default(:server_stats_interval)
    scheduler.schedule_every(
      every,
      :first_in => every,
      :tags     => [:status_update, schedule_category]
    ) { enqueue :miq_server_status_update }

    # Schedule - Log Server and Worker Statistics
    every = worker_setting_or_default(:server_log_stats_interval)
    scheduler.schedule_every(
      every,
      :first_in => every,
      :tags     => [:log_status, schedule_category]
    ) { enqueue :miq_server_worker_log_status }

    # Schedule - Periodic logging of database statistics
    interval = worker_setting_or_default(:db_diagnostics_interval, 30.minutes)
    scheduler.schedule_every(
      interval,
      :first_in => 1.minute,
      :tags     => [:log_statistics, schedule_category]
    ) { enqueue :vmdb_database_connection_log_statistics }

    # Schedule - Periodic check for updates on appliances only
    if MiqEnvironment::Command.is_appliance?
      interval = worker_setting_or_default(:yum_update_check, 12.hours)
      scheduler.schedule_every(
        interval,
        :first_in => 1.minute,
        :tags     => [:server_updates, schedule_category]
      ) { enqueue :miq_server_queue_update_registration_status }
    end

    # Schedule - Periodic resync of RHN Mirror
    if MiqEnvironment::Command.is_appliance? && MiqServer.my_server.has_assigned_role?("rhn_mirror")
      interval = worker_setting_or_default(:resync_rhn_mirror, 12.hours)
      scheduler.schedule_every(
        interval,
        :first_in => 1.minute,
        :tags     => [:rhn_mirror, schedule_category]
      ) { enqueue :miq_server_resync_rhn_mirror }
    end

    @schedules[:all]
  end

  def schedules_for_scheduler_role
    # These schedules need to run only once in a zone per interval, so let the single scheduler role handle them
    return unless schedule_enabled?(:scheduler)
    scheduler = scheduler_for(:scheduler)
    # Schedule - Check for timed out jobs
    every = worker_setting_or_default(:job_timeout_interval)
    scheduler.schedule_every(every, :first_in => every) do
      enqueue :job_check_jobs_for_timeout
    end

    # Schedule - Check for Retired Services
    every = worker_setting_or_default(:service_retired_interval)
    scheduler.schedule_every(every, :first_in => every) do
      enqueue :service_retirement_check
    end

    # Schedule - Check for Retired VMs
    every = worker_setting_or_default(:vm_retired_interval)
    scheduler.schedule_every(every, :first_in => every) do
      enqueue :vm_retirement_check
    end

    # Schedule - Check for Retired Orchestration Stacks
    every = worker_setting_or_default(:orchestration_stack_retired_interval)
    scheduler.schedule_every(every, :first_in => every) do
      enqueue :orchestration_stack_retirement_check
    end

    # Schedule - Check for Retired Load Balancers
    every = worker_setting_or_default(:load_balancer_retired_interval)
    scheduler.schedule_every(every, :first_in => every) do
      enqueue :load_balancer_retirement_check
    end

    # Schedule - Periodic validation of authentications
    every = worker_setting_or_default(:authentication_check_interval, 1.day)
    scheduler.schedule_every(every, :first_in => every) do
      # Queue authentication checks for CIs with credentials
      enqueue :host_authentication_check_schedule
      enqueue :ems_authentication_check_schedule
      enqueue :storage_authentication_check_schedule
    end

    # Schedule - Check for session timeouts
    scheduler.schedule_every(worker_setting_or_default(:session_timeout_interval)) do
      # Session is global to the region, therefore, run it only once on the scheduler's server
      enqueue :session_check_session_timeout
    end

    # Schedule - Check for rogue EVM snapshots
    every               = worker_setting_or_default(:evm_snapshot_interval, 1.hour)
    job_not_found_delay = worker_setting_or_default(:evm_snapshot_delete_delay_for_job_not_found, 1.hour)
    scheduler.schedule_every(every, :first_in => every) do
      enqueue [:job_check_for_evm_snapshots, job_not_found_delay]
    end

    # Queue a JobProxyDispatcher dispatch task at high priority unless there's already one on the queue
    # This dispatch method goes through all pending jobs to see if there's a free proxy available to work on one of them
    # It is very expensive to constantly do this, hence the need to ensure only one is on the queue at one time
    scheduler.schedule_every(worker_setting_or_default(:job_proxy_dispatcher_interval)) do
      enqueue :job_proxy_dispatcher_dispatch
    end

    stale_interval = worker_setting_or_default(:job_proxy_dispatcher_stale_message_check_interval, 60.seconds)
    threshold_seconds = worker_setting_or_default(:job_proxy_dispatcher_stale_message_timeout, 2.minutes)
    scheduler.schedule_every(stale_interval) do
      enqueue [:check_for_stuck_dispatch, threshold_seconds]
    end

    # Schedule - Hourly Alert Evaluation Timer
    scheduler.schedule_every(1.hour, :first_in => 5.minutes) do
      enqueue :miq_alert_evaluate_hourly_timer
    end

    # Schedule every 24 hours
    at = worker_setting_or_default(:storage_file_collection_time_utc)
    if Time.now.strftime("%Y-%m-%d #{at}").to_time(:utc) < Time.now.utc
      time_at = 1.day.from_now.utc.strftime("%Y-%m-%d #{at}").to_time(:utc)
    else
      time_at = Time.now.strftime("%Y-%m-%d #{at}").to_time(:utc)
    end
    scheduler.schedule_every(
      worker_setting_or_default(:storage_file_collection_interval),
      :first_at => time_at
    ) { enqueue :storage_scan_timer }

    schedule_settings_for_ems_refresh.each do |klass, every|
      scheduler.schedule_every(every, :first_in => every) do
        enqueue [:ems_refresh_timer, klass]
      end
    end

    # run run chargeback generation every day at specific time
    schedule_chargeback_report_for_service_daily
    @schedules[:scheduler]
  end

  def schedule_chargeback_report_for_service_daily
    every = worker_setting_or_default(:chargeback_generation_interval, 1.day)
    at = worker_setting_or_default(:chargeback_generation_time_utc, "01:00:00")
    time_at = Time.current.strftime("%Y-%m-%d #{at}").to_time(:utc)
    time_at += 1.day if time_at < Time.current + 1.hour
    scheduler = scheduler_for(:scheduler)
    scheduler.schedule_every(every, :first_at => time_at) do
      enqueue [:generate_chargeback_for_service, :report_source => "Daily scheduler"]
    end
  end

  def schedules_for_database_operations_role
    # Schedule - Database Metrics capture run by the appliance with a database_operations role
    return unless schedule_enabled?(:database_operations)
    scheduler = scheduler_for(:database_operations)
    cfg = VMDB::Config.new("vmdb").config

    sched = cfg.fetch_path(:database, :metrics_collection, :collection_schedule)
    _log.info("database_metrics_collection_schedule: #{sched}")
    scheduler.cron(
      sched,
      :tags => [:database_operations, :database_metrics_collection_schedule],
      :job  => true
    ) { enqueue :vmdb_database_capture_metrics_timer }

    sched = cfg.fetch_path(:database, :metrics_collection, :daily_rollup_schedule)
    _log.info("database_metrics_daily_rollup_schedule: #{sched}")
    scheduler.cron(
      sched,
      :tags => [:database_operations, :database_metrics_daily_rollup_schedule],
      :job  => true
    ) { enqueue :vmdb_database_rollup_metrics_timer }

    sched = cfg.fetch_path(:database, :metrics_history, :purge_schedule)
    _log.info("database_metrics_purge_schedule: #{sched}")
    scheduler.cron(
      sched,
      :tags => [:database_operations, :database_metrics_purge_schedule],
      :job  => true
    ) { enqueue :metric_purge_all_timer }

    @schedules[:database_operations]
  end

  def schedules_for_ldap_synchronization_role
    # These schedules need to run with the LDAP SYnchronizartion role
    return unless schedule_enabled?(:ldap_synchronization)
    scheduler = scheduler_for(:ldap_synchronization)
    ldap_synchronization_schedule_default = "0 2 * * *"
    ldap_synchronization_schedule         = [:ldap_synchronization, :ldap_synchronization_schedule]

    sched = VMDB::Config.new("vmdb").config.fetch_path(ldap_synchronization_schedule) || ldap_synchronization_schedule_default
    _log.info("ldap_synchronization_schedule: #{sched}")

    scheduler.cron(
      sched,
      :tags => [:ldap_synchronization, :ldap_synchronization_schedule],
      :job  => true
    ) { enqueue :ldap_server_sync_data_from_timer }

    @schedules[:ldap_synchronization]
  end

  def schedules_for_ems_metrics_coordinator_role
    # These schedules need to run by the servers with the coordinator role
    return unless schedule_enabled?("ems_metrics_coordinator")
    scheduler = scheduler_for(:ems_metrics_coordinator)
    # Schedule - Performance Collection and Performance Purging
    every    = worker_setting_or_default(:performance_collection_interval, 3.minutes)
    first_in = worker_setting_or_default(:performance_collection_start_delay, 5.minutes)
    scheduler.schedule_every(
      every,
      :first_in => first_in,
      :tags     => [:ems_metrics_coordinator, :perf_capture_timer]
    ) { enqueue :metric_capture_perf_capture_timer }

    every    = worker_setting_or_default(:performance_realtime_purging_interval, 15.minutes)
    first_in = worker_setting_or_default(:performance_realtime_purging_start_delay, 5.minutes)
    scheduler.schedule_every(
      every,
      :first_in => first_in,
      :tags     => [:ems_metrics_coordinator, :purge_realtime_timer]
    ) { enqueue :metric_purging_purge_realtime_timer }

    every    = worker_setting_or_default(:performance_rollup_purging_interval, 4.hours)
    first_in = worker_setting_or_default(:performance_rollup_purging_start_delay, 5.minutes)
    scheduler.schedule_every(
      every,
      :first_in => first_in,
      :tags     => [:ems_metrics_coordinator, :purge_rollup_timer]
    ) { enqueue :metric_purging_purge_rollup_timer }

    @schedules[:ems_metrics_coordinator]
  end

  def schedules_for_event_role
    # These schedules need to run by the servers with the event role
    return unless schedule_enabled?(:event)
    scheduler = scheduler_for(:event)
    # Schedule - Event Purging
    interval = worker_setting_or_default(:ems_events_purge_interval, 1.day)
    scheduler.schedule_every(
      interval,
      :first_in => "300s",
      :tags     => [:ems_event, :purge_schedule]
    ) { enqueue :ems_event_purge_timer }

    # Schedule - Policy Event Purging
    interval = worker_setting_or_default(:policy_events_purge_interval, 1.day)
    scheduler.schedule_every(
      interval,
      :first_in => "300s",
      :tags     => [:policy_event, :purge_schedule]
    ) { enqueue :policy_event_purge_timer }

    @schedules[:event]
  end

  def schedules_for_storage_metrics_coordinator_role
    # These schedules need to run by the servers with the coordinator role
    return unless schedule_enabled?(:storage_metrics_coordinator)
    scheduler = scheduler_for(:storage_metrics_coordinator)
    cfg = VMDB::Config.new("vmdb").config

    # Schedule - Storage metrics collection
    sched = cfg.fetch_path(:storage, :metrics_collection, :collection_schedule)
    _log.info("storage_metrics_collection_schedule: #{sched}")
    scheduler.cron(sched, :job => true) do
      enqueue :storage_refresh_metrics
    end

    # Schedule - Storage metrics hourly rollup
    sched = cfg.fetch_path(:storage, :metrics_collection, :hourly_rollup_schedule)
    _log.info("storage_metrics_hourly_rollup_schedule: #{sched}")
    scheduler.cron(sched, :job => true) do
      enqueue :storage_metrics_rollup_hourly
    end

    # Schedule - Storage metrics daily rollup
    base_sched = cfg.fetch_path(:storage, :metrics_collection, :daily_rollup_schedule)
    TimeProfile.rollup_daily_metrics.each do |tp|
      tz = ActiveSupport::TimeZone::MAPPING[tp.tz]
      sched = "#{base_sched} #{tz}"
      _log.info("storage_metrics_daily_rollup_schedule: #{sched}")
      scheduler.cron(sched, :job => true) do
        enqueue [:storage_metrics_rollup_daily, tp.id]
      end
    end

    # Schedule - Storage metrics purge
    sched = cfg.fetch_path(:storage, :metrics_history, :purge_schedule)
    _log.info("storage_metrics_purge_schedule: #{sched}")
    scheduler.cron(sched, :job => true) do
      enqueue :miq_storage_metric_purge_all_timer
    end

    # Schedule - Storage inventory collection
    sched = cfg.fetch_path(:storage, :inventory, :full_refresh_schedule)
    _log.info("storage_inventory_full_refresh_schedule: #{sched}")
    scheduler.cron(sched, :job => true) do
      enqueue :storage_refresh_inventory
    end

    @schedules[:storage_metrics_coordinator]
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
      enqueue [:miq_schedule_queue_scheduled_work, schedule_id, rufus_job]
    end
  end

  def rufus_add_monthly_schedule(options)
    months = options.delete(:months)
    method = options.delete(:method)
    interval = options.delete(:interval)
    schedule_id = options.delete(:schedule_id)

    # Treat months differently since rufus doesn't support :schedule_every with X.months type of options
    sch = MiqSchedule.find(schedule_id)
    next_run = sch.next_interval_time
    @schedules[:scheduler] << @user_scheduler.send(method, next_run, options.dup) do |rufus_job|
      enqueue [:miq_schedule_queue_scheduled_work, schedule_id, rufus_job]
    end

    # Schedule every X months for up to 5 years in the future
    remaining_months = ((5 * 12) / months) - 1
    remaining_months.times do
      next_run += months.months
      @schedules[:scheduler] << @user_scheduler.send(method, next_run, options.dup) do |rufus_job|
        enqueue [:miq_schedule_queue_scheduled_work, schedule_id, rufus_job]
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
            if j.kind_of?(Fixnum)
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
    config = VMDB::Config.new("vmdb").config.fetch(:ems_refresh, {})

    ExtManagementSystem.leaf_subclasses.each.with_object({}) do |klass, hash|
      next unless klass.ems_type

      every   = config.fetch_path(klass.ems_type.to_sym, :refresh_interval)
      every ||= config.fetch(:refresh_interval, 24.hours)

      every   = every.respond_to?(:to_i_with_method) ? every.to_i_with_method : every.to_i

      hash[klass] = every unless every == 0
    end
  end
end
