class MiqVimBrokerWorker::Runner < MiqWorker::Runner
  self.wait_for_worker_monitor = false

  def after_initialize
    require 'thread'

    # Global Work Queue
    @queue = Queue.new

    @initial_emses_to_monitor, invalid_emses = MiqVimBrokerWorker.emses_to_monitor.partition { |e| e.authentication_check.first }
    start_broker_server(@initial_emses_to_monitor)
    @worker.update_attributes(:uri => DRb.uri)
    _log.info("#{log_prefix} DRb URI: #{DRb.uri}")

    invalid_emses.each do |e|
      _log.warn("#{log_prefix} Not monitoring Management System #{e.name} since it failed authentication check")
    end

    reset_broker_update_notification
    reset_broker_update_sleep_interval
  end

  def self.emses_and_hosts_to_monitor
    emses = MiqVimBrokerWorker.emses_to_monitor
    MiqPreloader.preload(emses, :hosts => :authentications)
    hosts = emses.collect(&:hosts).flatten.uniq.select(&:authentication_status_ok?)
    emses + hosts
  end

  def after_sync_config
    reset_broker_update_sleep_interval unless @vim_broker_server.nil?
  end

  def after_sync_active_roles
    check_broker_cache_scope unless @vim_broker_server.nil?
  end

  def reset_broker_update_sleep_interval
    waitForUpdates_sleep = worker_settings[:vim_broker_update_interval]
    waitForUpdates_sleep = nil unless waitForUpdates_sleep.kind_of?(Numeric)
    waitForUpdates_sleep = nil if     waitForUpdates_sleep == 0
    if @waitForUpdates_sleep != waitForUpdates_sleep
      pretty = waitForUpdates_sleep.nil? ? "NONE" : "#{waitForUpdates_sleep} seconds"
      _log.info("#{log_prefix} Setting Broker's Update Manager's Sleep Interval to [#{pretty}]")
      @vim_broker_server.updateDelay = waitForUpdates_sleep
      @waitForUpdates_sleep = waitForUpdates_sleep
    end
  end

  def reset_broker_update_notification
    @active_roles.include?("ems_inventory") ? enable_broker_update_notification : disable_broker_update_notification
  end

  def enable_broker_update_notification
    return if @notification_enabled

    _log.info("#{log_prefix} Enabling Broker's Update Manager Notification")

    @exclude_props = VMDB::Config.new("broker_notify_properties").config[:exclude] || {}
    @exclude_props.stringify_keys! # TODO: Remove when we clean up cfg yamls

    if @exclude_props.empty?
      _log.info("#{log_prefix} Not excluding any properties for broker notification.")
    else
      _log.info("#{log_prefix} Using the following broker properties exclude list:")
      $log.log_hashes(@exclude_props)
    end

    @ems_ids_for_notify = MiqVimBrokerWorker.emses_to_monitor.each_with_object({}) { |e, h| h[[e.address, e.authentication_userid]] = e.id }

    # Set notify method at the class level for new connections, and at the
    #   instance level for existing connections.
    MiqVimBroker.notifyMethod = @vim_broker_server.notifyMethod = ->(h) { @queue.enq h }

    @notification_enabled = true
  end

  def disable_broker_update_notification
    return unless @notification_enabled

    _log.info("#{log_prefix} Disabling Broker's Update Manager Notification")

    # Set notify method at the class level for new connections, and at the
    #   instance level for existing connections.
    MiqVimBroker.notifyMethod = @vim_broker_server.notifyMethod = nil

    @ems_ids_for_notify = nil
    @notification_enabled = false
  end

  def check_broker_cache_scope
    do_exit("Exiting due to change in broker cache scope.") if MiqVimBroker.cacheScope != expected_broker_cache_scope
  end

  def expected_broker_cache_scope
    @active_roles.include?("ems_inventory") ? :cache_scope_ems_refresh : :cache_scope_core
  end

  def ems_ids_for_notify(address, userid)
    return unless @notification_enabled

    key = [address, userid]
    ret = @ems_ids_for_notify[key] || begin
      zone_id = MiqServer.my_server.zone_id
      ems = ManageIQ::Providers::Vmware::InfraManager
        .includes(:authentications)
        .where(:zone_id => zone_id)
        .detect { |e| e.hostname == address && e.authentication_userid == userid }
      ems_id = ems.nil? ? :ignore : ems.id
      _log.warn("#{log_prefix} Ignoring updates for unknown connection, address: [#{address}], userid: [#{userid}]") if ems_id == :ignore
      @ems_ids_for_notify[key] = ems_id
    end
    ret == :ignore ? nil : ret
  end

  def do_before_work_loop
    if @active_roles.include?("ems_inventory") && @initial_emses_to_monitor.length > 0
      _log.info("#{log_prefix} Queueing initial refresh for EMS.")
      EmsRefresh.queue_refresh(@initial_emses_to_monitor)
    end
  end

  def log_status
    t = Time.now.utc
    interval = worker_settings[:vim_broker_status_interval] || 15.minutes
    interval = 1.minute if interval < 1.minute
    if @last_status_interval.nil? || @last_status_interval + interval < t
      @last_status_interval = t
      Thread.new { @vim_broker_server.logStatus } unless @vim_broker_server.nil?
    end
  end

  def do_work
    while @queue.length > 0
      heartbeat
      check_connections
      drain_event
      Thread.pass
    end
  end

  def do_heartbeat_work
    t = Benchmark.realtime { check_broker_server }
    _log.warn("#{log_prefix} Elapsed time for [check_broker_server] was #{t} seconds") if t > 30
    log_status
  end

  def drain_event
    event = @queue.deq
    return if event.nil?

    method = "on_#{event[:op].to_s.underscore}_event"
    send(method, event) if self.respond_to?(method)
  end

  def on_notify_event(event)
    ems_id = ems_ids_for_notify(event[:server], event[:username])
    return if ems_id.nil?
    _log.info("Queueing update for EMS id: [#{ems_id}] on event [#{event[:objType]}-#{event[:op]}]#{" for properties: #{event[:changedProps].inspect}" if event.key?(:changedProps)}")
    EmsRefresh.queue_vc_update(ems_id, event)
  end
  alias_method :on_create_event, :on_notify_event
  alias_method :on_delete_event, :on_notify_event

  def on_update_event(event)
    obj_type, changed_props, change_set = event.values_at(:objType, :changedProps, :changeSet)

    type, = EmsRefresh::VcUpdates::OBJ_TYPE_TO_TYPE_AND_CLASS[obj_type]

    changed_props.reject! { |p| !EmsRefresh::VcUpdates.selected_property?(type, p) }
    change_set.reject!    { |c| !EmsRefresh::VcUpdates.selected_property?(type, c["name"]) }

    exclude_props = @exclude_props[obj_type]
    unless exclude_props.nil?
      changed_props.reject! { |p| exclude_props.key?(p) }
      change_set.reject!    { |c| exclude_props.key?(c["name"]) }
    end

    return if changed_props.empty?

    on_notify_event(event)
  end

  def on_miq_vim_removed_event(event)
    return unless event[:op] == 'MiqVimRemoved'

    _log.info("#{log_prefix} Attempting to reconnect broker for EMS with address: [#{event[:server]}] due to error: #{event[:error]}")

    ems = ManageIQ::Providers::Vmware::InfraManager.find_by(:hostname => event[:server])
    if ems.nil?
      _log.error "#{log_prefix} Unable to find EMS with address: [#{event[:server]}]"
      return
    end

    reconnect_ems(ems)
  end

  def drain_queue
    drain_event while @queue.length > 0
  end

  def before_exit(message, _exit_code)
    # Gracefully Shutdown the Broker
    if @vim_broker_server
      safe_log("#{message} Stopping Broker.")
      @vim_broker_server.shutdown rescue nil
    end

    # Drain the Queue of the Vim Events
    if @queue
      safe_log("#{message} Draining Event Queue.")
      drain_queue rescue nil
    end
  end

  def create_miq_vim_broker_server
    require 'MiqVim'
    require 'MiqVimBroker'

    MiqVimBroker.preLoad      = true
    MiqVimBroker.debugUpdates = false
    MiqVimBroker.updateDelay  = nil
    MiqVimBroker.notifyMethod = nil
    MiqVimBroker.cacheScope   = expected_broker_cache_scope
    MiqVimBroker.setSelector(EmsRefresh::VcUpdates::VIM_SELECTOR_SPEC)

    _log.info("#{log_prefix} Creating broker server with [#{MiqVimBroker.cacheScope}]")

    @vim_broker_server = MiqVimBroker.new(:server, 0)   # Port 0 means to let it pick any available port
  end

  def start_broker_server(emses_to_prime = nil)
    _log.info("#{log_prefix} Starting broker server...")

    @waitForUpdates_sleep = nil
    @notification_enabled = false
    create_miq_vim_broker_server
    prime_all_ems(emses_to_prime) if emses_to_prime

    _log.info("#{log_prefix} Starting broker server...Complete")
  rescue => err
    _log.warn("#{log_prefix} Unable to start broker server, '#{err.message}', will retry later")
  end

  def prime_all_ems(emses)
    _log.info("#{log_prefix} Priming cache with data from attached Management Systems") unless emses.blank?
    emses.each do |ems|
      @worker.update_heartbeat # heartbeat in between each EMS to prevent long timeout
      prime_ems(ems)
    end
  end

  def prime_ems(ems)
    _log.info("#{log_prefix} Preloading broker for EMS: [#{ems.name}]...")
    preload(ems)
    _log.info("#{log_prefix} Preloading broker for EMS: [#{ems.name}]...Complete")
  rescue Timeout::Error, StandardError => err
    _log.warn("#{log_prefix} Preloading broker for EMS: [#{ems.name}]...Failed. Error: #{err.message}")
  end

  def reconnect_ems(ems)
    begin
      _log.info("#{log_prefix} Reconnecting broker for EMS: [#{ems.name}]...")
      preload(ems)
      _log.info("#{log_prefix} Reconnecting broker for EMS: [#{ems.name}]...Complete")
    rescue Timeout::Error, StandardError => err
      _log.warn("#{log_prefix} Reconnecting broker for EMS: [#{ems.name}]...Failed. Retrying. Error: #{err.message}")
      self.class.corresponding_model.queue_reconnect_ems(ems)
      return
    end

    _log.info("#{log_prefix} Queueing full refresh for EMS: [#{ems.name}] due to reconnect")
    EmsRefresh.queue_refresh(ems)
  end

  def preload(ems)
    vim = @vim_broker_server.getMiqVim(ems.address, *ems.auth_user_pwd)
  ensure
    vim.disconnect rescue nil
  end

  def check_broker_server
    do_exit("Broker Server is no longer alive, restarting...", 1) unless DRb.thread && DRb.thread.alive?
  end

  def message_broker_unavailable(*_args)
    _log.warn("#{log_prefix} 'broker unavailable' was reported, connection will be restored on next heartbeat")
  end

  def message_broker_too_many_files(*_args)
    _log.warn("#{log_prefix} 'broker Errno::EMFILE' was reported, broker worker restarting")
    do_exit("'broker Errno::EMFILE' was reported", 1)
  end

  def message_reconnect_ems(*args)
    return if args.empty?
    ems_id = args.first.to_i

    ems = ManageIQ::Providers::Vmware::InfraManager.find_by(:id => ems_id)
    if ems.nil?
      _log.error "#{log_prefix} Unable to find EMS with id: [#{ems_id}]"
      return
    end

    reconnect_ems(ems)
  end

  # Determines if the broker is still holding and updating connections for EMSes
  #   or Hosts that we no longer manage, or for which the username or address
  #   has changed.
  def check_connections
    t = Time.now.utc
    if @last_check_connections.nil? || @last_check_connections + 15.minutes < t
      @last_check_connections = t

      # Find all EMSes and Hosts to which we could have connections.
      connections = self.class.emses_and_hosts_to_monitor.collect { |e| [e.address, e.authentication_userid] }
      (@vim_broker_server.connectionInfo - connections).each do |c|
        _log.info("#{log_prefix} Connection #{c.inspect} is no longer active.  Reporting to broker.")
        @vim_broker_server.removeMiqVim(*c)
      end
    end
  end
end
