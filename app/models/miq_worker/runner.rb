require 'miq-process'
require 'thread'

class MiqWorker::Runner
  class TemporaryFailure < RuntimeError
  end

  include Vmdb::Logging
  attr_accessor :last_hb, :worker, :worker_settings
  attr_reader   :active_roles, :server

  INTERRUPT_SIGNALS = ["SIGINT", "SIGTERM"]

  # DELETE ME
  OPTIONS_PARSER_SETTINGS = [
    [:guid,       'EVM Worker GUID',       String],
  ]

  SAFE_SLEEP_SECONDS = 60

  def self.start_worker(*args)
    new(*args).start
  end

  def poll_method
    return @poll_method unless @poll_method.nil?
    self.poll_method = worker_settings[:poll_method]
  end

  def poll_method=(val)
    val = "sleep_poll_#{val}"
    raise ArgumentError, _("poll method '%{value}' not defined") % {:value => val} unless respond_to?(val)
    @poll_method = val.to_sym
  end

  def self.corresponding_model
    parent
  end

  def self.interrupt_signals
    INTERRUPT_SIGNALS
  end

  def initialize(cfg = {})
    @cfg = cfg
    $log ||= Rails.logger

    @server = MiqServer.my_server(true)
    @sigterm_received = false

    worker_initialization
    after_initialize

    @worker.release_db_connection if @worker.respond_to?(:release_db_connection)
  end

  def worker_initialization
    starting_worker_record
    set_process_title
    # Sync the config and roles early since heartbeats and logging require the configuration
    sync_config

    set_connection_pool_size
  end

  # More process specific stuff :-(
  def set_database_application_name
    ArApplicationName.name = @worker.database_application_name
  end

  def set_connection_pool_size
    cur_size = ActiveRecord::Base.connection_pool.instance_variable_get(:@size)
    new_size = worker_settings[:connection_pool_size] || cur_size
    return if cur_size == new_size

    ActiveRecord::Base.connection_pool.instance_variable_set(:@size, new_size)
    _log.info("#{log_prefix} Changed connection_pool size from #{cur_size} to #{new_size}")
  end

  ###############################
  # Worker Monitor Methods
  ###############################

  def worker_monitor_drb
    @worker_monitor_drb ||= begin
      raise _("%{log} No MiqServer found to establishing DRb Connection to") % {:log => log_prefix} if server.nil?
      drb_uri = server.reload.drb_uri
      if drb_uri.blank?
        raise _("%{log} Blank DRb_URI for MiqServer with ID=[%{number}], NAME=[%{name}], PID=[%{pid_number}], GUID=[%{guid_number}]") %
          {:log         => log_prefix,
           :number      => server.id,
           :name        => server.name,
           :pid_number  => server.pid,
           :guid_number => server.guid}
      end
      _log.info("#{log_prefix} Initializing DRb Connection to MiqServer with ID=[#{server.id}], NAME=[#{server.name}], PID=[#{server.pid}], GUID=[#{server.guid}] DRb URI=[#{drb_uri}]")
      require 'drb'
      DRbObject.new(nil, drb_uri)
    end
  end

  ###############################
  # VimBrokerWorker Methods
  ###############################

  def self.delay_startup_for_vim_broker?
    !!@delay_startup_for_vim_broker
  end

  class << self
    attr_writer :delay_startup_for_vim_broker
  end

  def self.delay_queue_delivery_for_vim_broker?
    !!@delay_queue_delivery_for_vim_broker
  end

  class << self
    attr_writer :delay_queue_delivery_for_vim_broker

    alias require_vim_broker? delay_queue_delivery_for_vim_broker?
    alias require_vim_broker= delay_queue_delivery_for_vim_broker=
  end

  def start
    prepare
    run

  rescue SignalException => e
    if e.kind_of?(Interrupt) || self.class.interrupt_signals.include?(e.message)
      do_exit("Interrupt signal (#{e}) received.")
    else
      raise
    end
  end

  def recover_from_temporary_failure
    @backoff ||= 30
    @backoff *= 2 if @backoff < 4.hours
    safe_sleep(@backoff)
  end

  def prepare
    set_database_application_name
    ObjectSpace.garbage_collect
    started_worker_record
    do_delay_startup_for_vim_broker if self.class.delay_startup_for_vim_broker? && MiqVimBrokerWorker.workers > 0
    do_before_work_loop
    self
  end

  def run
    do_work_loop
  end

  def log_prefix
    @log_prefix ||= "MIQ(#{self.class.name})"
  end

  #
  # @worker object handling methods
  #

  def find_worker_record
    @worker = self.class.corresponding_model.find_by(:guid => @cfg[:guid])
    do_exit("Unable to find instance for worker GUID [#{@cfg[:guid]}].", 1) if @worker.nil?
  end

  def starting_worker_record
    find_worker_record
    @worker.status         = "starting"
    @worker.started_on     = Time.now.utc
    @worker.last_heartbeat = Time.now.utc
    @worker.update_spid
    @worker.save
  end

  def started_worker_record
    reload_worker_record
    @worker.status         = "started"
    @worker.last_heartbeat = Time.now.utc
    @worker.update_spid
    @worker.save
    $log.info("#{self.class.name} started. ID [#{@worker.id}], PID [#{@worker.pid}], GUID [#{@worker.guid}], Zone [#{MiqServer.my_zone}], Role [#{MiqServer.my_role}]")
  end

  def reload_worker_record
    worker_id   = @worker.id
    worker_guid = @worker.guid
    begin
      @worker.reload
    rescue ActiveRecord::RecordNotFound
      do_exit("Unable to find instance for worker ID [#{worker_id}] GUID [#{worker_guid}].", 1)
    end
  end

  #
  # Worker exit methods
  #

  def safe_log(message = nil, exit_code = 0)
    meth = (exit_code == 0) ? :info : :error

    prefix = "#{log_prefix} "      rescue ""
    pid    = "PID [#{Process.pid}] "    rescue ""
    guid   = @worker.nil? ? '' : "GUID [#{@worker.guid}] "  rescue ""
    id     = @worker.nil? ? '' : "ID [#{@worker.id}] "      rescue ""
    logmsg = "#{prefix}#{id}#{pid}#{guid}#{message}"

    begin
      $log.send(meth, logmsg)
    rescue
      puts "#{meth.to_s.upcase}: #{logmsg}" rescue nil
    end
  end

  def update_worker_record_at_exit(exit_code)
    return if @worker.nil?

    @worker.reload
    @worker.status     = exit_code == 0 ? MiqWorker::STATUS_STOPPED : MiqWorker::STATUS_ABORTED
    @worker.stopped_on = Time.now.utc
    @worker.save

    @worker.status_update
    @worker.log_status
  end

  def do_exit(message = nil, exit_code = 0)
    return if @exiting # Prevent running the do_exit logic more than one time
    @exiting = true

    begin
      before_exit(message, exit_code)
    rescue Exception => e
      safe_log("Error in before_exit: #{e.message}", :error)
    end

    begin
      update_worker_record_at_exit(exit_code)
    rescue Exception => e
      safe_log("Error in update_worker_record_at_exit: #{e.message}", :error)
    end

    begin
      MiqWorker.release_db_connection
    rescue Exception => e
      safe_log("Error in releasing database connection: #{e.message}", :error)
    end

    safe_log("#{message} Worker exiting.", exit_code)
  ensure
    exit exit_code
  end

  #
  # Message handling methods
  #

  def message_exit(*_args)
    do_exit("Exit request received.")
  end

  def message_restarted(*_args)
    # just consume the restarted message
  end

  def message_sync_config(*_args)
    _log.info("#{log_prefix} Synchronizing configuration...")
    sync_config
    _log.info("#{log_prefix} Synchronizing configuration complete...")
  end

  def sync_config
    # Sync roles
    @active_roles = MiqServer.my_active_roles(true)
    after_sync_active_roles

    # Sync settings
    Vmdb::Settings.reload!
    @my_zone ||= MiqServer.my_zone
    sync_log_level
    sync_worker_settings
    sync_blacklisted_events
    after_sync_config

    _log.info("ID [#{@worker.id}], PID [#{Process.pid}], GUID [#{@worker.guid}], Zone [#{@my_zone}], Active Roles [#{@active_roles.join(',')}], Assigned Roles [#{MiqServer.my_role}], Configuration:")
    $log.log_hashes(@worker_settings)
    $log.info("---")
    $log.log_hashes(@cfg)

    @worker.release_db_connection if @worker.respond_to?(:release_db_connection)
  end

  def sync_log_level
    # TODO: Can this be removed since the Vmdb::Settings::Activator will do this anyway?
    Vmdb::Loggers.apply_config(::Settings.log)
  end

  def sync_worker_settings
    @worker_settings = self.class.corresponding_model.worker_settings(:config => ::Settings.to_hash)
    @poll = @worker_settings[:poll]
    poll_method
  end

  #
  # Work methods
  #

  def do_work
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def do_delay_startup_for_vim_broker
    _log.info("#{log_prefix} Checking that VIM Broker has started before doing work")
    loop do
      break if MiqVimBrokerWorker.available?
      heartbeat
      sleep 3
    end
    _log.info("#{log_prefix} Starting work since VIM Broker has started")
  end

  def do_work_loop
    warn_about_heartbeat_skipping if skip_heartbeat?
    loop do
      begin
        heartbeat
        do_work
      rescue TemporaryFailure => error
        msg = "#{log_prefix} Temporary failure (message: '#{error}') caught"\
            " during #do_work. Sleeping for a while before resuming."
        _log.warn(msg)
        recover_from_temporary_failure
      rescue SystemExit
        do_exit("SystemExit signal received.  ")
      rescue => err
        do_exit("An error has occurred during work processing: #{err}\n#{err.backtrace.join("\n")}", 1)
      else
        @backoff = nil
      end

      # Should be caught by the rescue in `#start` and will run do_exit from
      # there.
      raise Interrupt if @sigterm_received

      do_gc
      self.class.log_ruby_object_usage(worker_settings[:top_ruby_object_classes_to_log].to_i)
      send(poll_method)
    end
  end

  def heartbeat
    now = Time.now.utc
    # Heartbeats can be expensive, so do them only when needed
    return if @last_hb.kind_of?(Time) && (@last_hb + worker_settings[:heartbeat_freq]) >= now

    ENV["WORKER_HEARTBEAT_METHOD"] == "file" ? heartbeat_to_file : heartbeat_to_drb
    @last_hb = now
    do_heartbeat_work
  rescue SystemExit, SignalException
    raise
  rescue Exception => err
    do_exit("Error heartbeating because #{err.class.name}: #{err.message}\n#{err.backtrace.join('\n')}", 1)
  end

  def heartbeat_to_drb
    # Disable heartbeat check.  Useful if a worker is running in isolation
    # without the oversight of MiqServer::WorkerManagement
    return if skip_heartbeat?

    messages = worker_monitor_drb.worker_heartbeat(@worker.pid, @worker.class.name, @worker.queue_name)
    messages.each { |msg, *args| process_message(msg, *args) }
  rescue DRb::DRbError => err
    do_exit("Error heartbeating to MiqServer because #{err.class.name}: #{err.message}", 1)
  end

  def heartbeat_to_file(timeout = nil)
    timeout ||= worker_settings[:heartbeat_timeout] || Workers::MiqDefaults.heartbeat_timeout
    File.write(@worker.heartbeat_file, (Time.now.utc + timeout).to_s)

    get_messages.each { |msg, *args| process_message(msg, *args) }
  end

  def get_messages
    messages = []
    @my_last_config_change ||= Time.now.utc

    last_config_change = server_last_change(:last_config_change)
    if last_config_change && last_config_change > @my_last_config_change
      _log.info("#{log_prefix} Configuration has changed, New TS: #{last_config_change}, Old TS: #{@my_last_config_change}")
      messages << ["sync_config"]

      @my_last_config_change = last_config_change
    end

    messages
  end

  def key_store
    require 'dalli'
    @key_store ||= Dalli::Client.new(MiqMemcached.server_address, :namespace => "server_monitor")
  end

  def server_last_change(key)
    key_store.get(key)
  end

  def do_gc
    t = Time.now.utc
    interval = worker_settings[:gc_interval] || 15.minutes
    interval = 1.minute if interval < 1.minute
    if @last_gc.nil? || @last_gc + interval < t
      gc_time = Benchmark.realtime { ObjectSpace.garbage_collect }
      gc_meth = gc_time >= 5 ? :warn : :debug
      $log.send(gc_meth, "#{log_prefix} Garbage collection took #{gc_time} seconds")
      @last_gc = t
    end
  end

  #
  # For derived classes to override, if they need to
  #
  def do_heartbeat_work
  end

  def do_before_work_loop
  end

  def after_initialize
  end

  def after_sync_config
  end

  def after_sync_active_roles
  end

  def before_exit(_message, _exit_code)
  end

  def sync_blacklisted_events
  end

  #
  # Polling methods
  #

  def sleep_poll_normal
    sleep(@poll)
  end

  def sleep_poll_escalate
    @poll_escalate = @poll_escalate.nil? ? @poll : @poll_escalate * 2
    @poll_escalate = worker_settings[:poll_escalate_max] if @poll_escalate > worker_settings[:poll_escalate_max]
    sleep(@poll_escalate)
  end

  def reset_poll_escalate
    @poll_escalate = nil
  end

  def safe_sleep(seconds)
    (seconds / SAFE_SLEEP_SECONDS).times do
      sleep SAFE_SLEEP_SECONDS
      heartbeat
    end
    sleep(seconds % SAFE_SLEEP_SECONDS)
  end

  def self.ruby_object_usage
    types = Hash.new { |h, k| h[k] = 0 }
    ObjectSpace.each_object do |obj|
      types[obj.class.name] += 1
    end
    types
  end

  LOG_RUBY_OBJECT_USAGE_INTERVAL = 60
  def self.log_ruby_object_usage(top = 20)
    return unless top > 0

    t = Time.now.utc
    @last_ruby_object_usage ||= t

    if (@last_ruby_object_usage + LOG_RUBY_OBJECT_USAGE_INTERVAL) < t
      types = ruby_object_usage
      _log.info("Ruby Object Usage: #{types.sort_by { |_k, v| -v }.take(top).inspect}")
      @last_ruby_object_usage = t
    end
  end

  # Traps both SIGTERM and SIGINT here, and does the same thing, but in a
  # container based deployment, SIGTERM is probably the one that will be
  # received from the container management system (aka OpenShift).  The SIGINT
  # trap is mostly a developer convenience.
  def setup_sigterm_trap
    Kernel.trap("TERM") { @sigterm_received = true }
    Kernel.trap("INT")  { @sigterm_received = true }
  end

  protected

  def process_message(message, *args)
    meth = "message_#{message}"
    if self.respond_to?(meth)
      send(meth, *args)
    else
      _log.warn("#{log_prefix} Message [#{message}] is not recognized, ignoring")
    end
  end

  def clean_broker_connection
    if $vim_broker_client
      $vim_broker_client.releaseSession(Process.pid)
      $vim_broker_client = nil
    end
  rescue => err
    _log.info("#{log_prefix} Releasing any broker connections for pid: [#{Process.pid}], ERROR: #{err.message}")
  end

  def process_title
    type   = @worker.abbreviated_class_name
    title  = "#{MiqWorker::PROCESS_TITLE_PREFIX} #{type} id: #{@worker.id}"
    title << ", queue: #{@worker.queue_name}" if @worker.queue_name
    title << ", uri: #{@worker.uri}" if @worker.uri
    title
  end

  def set_process_title
    Process.setproctitle(process_title)
  end

  private

  def skip_heartbeat?
    ENV["DISABLE_MIQ_WORKER_HEARTBEAT"]
  end

  def warn_about_heartbeat_skipping
    puts "**************************************************"
    puts "WARNING:  SKIPPING HEARTBEATING WITH THIS WORKER!"
    puts "**************************************************"
    puts ""
    puts "Remove the `DISABLE_MIQ_WORKER_HEARTBEAT` ENV variable"
    puts "to reenable heartbeating normally."
  end
end
