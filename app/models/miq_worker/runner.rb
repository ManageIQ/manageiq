require 'miq-process'
require 'thread'

class MiqWorker::Runner
  include Vmdb::Logging
  attr_accessor :last_hb, :worker, :worker_settings
  attr_reader   :vmdb_config, :active_roles, :server

  INTERRUPT_SIGNALS = ["SIGINT", "SIGTERM"]

  OPTIONS_PARSER_SETTINGS = [
    [:guid,       'EVM Worker GUID',       String],
  ]

  def self.start_worker(*args)
    cfg = {}
    opts = OptionParser.new
    self::OPTIONS_PARSER_SETTINGS.each do |key, desc, type|
      opts.on("--#{key} VAL", desc, type) { |v| cfg[key] = v }
    end
    opts.parse(*args)

    # Start the worker object
    new(cfg).start
  end

  def poll_method
    return @poll_method unless @poll_method.nil?
    self.poll_method = worker_settings[:poll_method]
  end

  def poll_method=(val)
    val = "sleep_poll_#{val}"
    raise ArgumentError, "poll method '#{val}' not defined" unless self.respond_to?(val)
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
    @cfg[:guid] ||= ENV['MIQ_GUID']

    $log ||= Rails.logger

    @server = MiqServer.my_server(true)

    worker_initialization
    after_initialize

    @worker.release_db_connection if @worker.respond_to?(:release_db_connection)
  end

  def worker_initialization
    starting_worker_record

    # Sync the config and roles early since heartbeats and logging require the configuration
    sync_active_roles
    sync_config

    set_connection_pool_size
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

  def self.wait_for_worker_monitor?
    @wait_for_worker_monitor = true if @wait_for_worker_monitor.nil?
    @wait_for_worker_monitor
  end

  class << self
    attr_writer :wait_for_worker_monitor
  end

  def my_monitor_started?
    return @monitor_started unless @monitor_started.nil?
    return false if     server.nil?
    return false unless server.reload.started?
    @monitor_started = true
  end

  def worker_monitor_drb
    raise "#{log_prefix} No MiqServer found to establishing DRb Connection to" if server.nil?
    drb_uri = server.reload.drb_uri
    raise "#{log_prefix} Blank DRb_URI for MiqServer with ID=[#{server.id}], NAME=[#{server.name}], PID=[#{server.pid}], GUID=[#{server.guid}]"    if drb_uri.blank?
    _log.info("#{log_prefix} Initializing DRb Connection to MiqServer with ID=[#{server.id}], NAME=[#{server.name}], PID=[#{server.pid}], GUID=[#{server.guid}] DRb URI=[#{drb_uri}]")
    require 'drb'
    DRbObject.new(nil, drb_uri)
  end

  ###############################
  # VimBrokerWorker Methods
  ###############################

  def self.require_vim_broker?
    @require_vim_broker = false if @require_vim_broker.nil?
    @require_vim_broker
  end

  class << self
    attr_writer :require_vim_broker
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

  def prepare
    ObjectSpace.garbage_collect
    started_worker_record
    do_wait_for_worker_monitor if self.class.wait_for_worker_monitor?
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
    @worker = self.class.corresponding_model.find_by_guid(@cfg[:guid])
    do_exit("Unable to find instance for worker GUID [#{@cfg[:guid]}].", 1) if @worker.nil?
  end

  def starting_worker_record
    find_worker_record
    @worker.pid            = Process.pid
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
    $log.info("#{self.class.name} started. ID [#{@worker.id}], PID [#{Process.pid}], GUID [#{@worker.guid}], Zone [#{MiqServer.my_zone}], Role [#{MiqServer.my_role}]")
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

  def message_sync_active_roles(*args)
    _log.info("#{log_prefix} Synchronizing active roles...")
    opts = args.extract_options!
    sync_active_roles(opts[:roles])
    _log.info("#{log_prefix} Synchronizing active roles complete...")
  end

  def message_sync_config(*args)
    _log.info("#{log_prefix} Synchronizing configuration...")
    opts = args.extract_options!
    sync_config(opts[:config])
    _log.info("#{log_prefix} Synchronizing configuration complete...")
  end

  def sync_config(config = nil)
    @vmdb_config = config || VMDB::Config.new("vmdb")
    @my_zone ||= MiqServer.my_zone
    sync_log_level
    sync_worker_settings
    sync_blacklisted_events
    _log.info("ID [#{@worker.id}], PID [#{Process.pid}], GUID [#{@worker.guid}], Zone [#{@my_zone}], Active Roles [#{@active_roles.join(',')}], Assigned Roles [#{MiqServer.my_role}], Configuration:")
    $log.log_hashes(@worker_settings)
    $log.info("---")
    $log.log_hashes(@cfg)
    after_sync_config
    @worker.release_db_connection if @worker.respond_to?(:release_db_connection)
  end

  def sync_log_level
    Vmdb::Loggers.apply_config(@vmdb_config.config[:log])
  end

  def sync_worker_settings
    @worker_settings = self.class.corresponding_model.worker_settings(:config => @vmdb_config)
    @poll = @worker_settings[:poll]
    poll_method
  end

  def sync_active_roles(role_names = nil)
    @active_roles = role_names || MiqServer.my_active_roles(true)
    after_sync_active_roles
  end

  #
  # Work methods
  #

  def do_work
    raise NotImplementedError, "must be implemented in a subclass"
  end

  def do_wait_for_worker_monitor
    _log.info("#{log_prefix} Checking that worker monitor has started before doing work")
    loop do
      break if self.my_monitor_started?
      heartbeat
      sleep 3
    end
    _log.info("#{log_prefix} Starting work since worker monitor has started")
  end

  def do_work_loop
    loop do
      begin
        heartbeat
        do_work
      rescue SystemExit
        do_exit("SystemExit signal received.  ")
      rescue => err
        do_exit("An error has occurred during work processing: #{err}\n#{err.backtrace.join("\n")}", 1)
      end

      do_gc
      send(poll_method)
    end
  end

  def heartbeat
    now = Time.now.utc
    # Heartbeats can be expensive, so do them only when needed
    return if @last_hb.kind_of?(Time) && (@last_hb + worker_settings[:heartbeat_freq]) >= now
    @worker_monitor_drb ||= worker_monitor_drb
    messages = @worker_monitor_drb.worker_heartbeat(@worker.pid, @worker.class.name, @worker.queue_name)
    @last_hb = now
    log_ruby_object_usage(worker_settings[:log_top_ruby_objects_on_heartbeat].to_i)
    messages.each { |msg, *args| process_message(msg, *args) }
    do_heartbeat_work
  rescue DRb::DRbError => err
    do_exit("Error heartbeating to MiqServer because #{err.class.name}: #{err.message}", 1)
  rescue SystemExit, SignalException
    raise
  rescue Exception => err
    do_exit("Error heartbeating because #{err.class.name}: #{err.message}\n#{err.backtrace.join('\n')}", 1)
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

  def ruby_object_usage
    types = Hash.new { |h, k| h[k] = Hash.new(0) }
    ObjectSpace.each_object do |obj|
      types[obj.class][:count] += 1
      next if obj.kind_of?(DRbObject) || obj.kind_of?(WeakRef)
      if obj.respond_to?(:length)
        len = obj.length
        if len.kind_of?(Numeric)
          types[obj.class][:max]    = len if len > types[obj.class][:max]
          types[obj.class][:total] += len
        end
      end
    end
    types
  end

  def log_ruby_object_usage(top = 20)
    if top > 0
      types = ruby_object_usage
      $log.info("Ruby Object Usage: #{types.sort_by { |_klass, h| h[:count] }.reverse[0, top].inspect}")
    end
  end
end
