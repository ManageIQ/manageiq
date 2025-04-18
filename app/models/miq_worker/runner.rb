require 'miq-process'

class MiqWorker::Runner
  class TemporaryFailure < RuntimeError
  end

  include Vmdb::Logging
  attr_accessor :last_hb, :worker, :worker_settings
  attr_reader   :active_roles, :server

  delegate :systemd_worker?, :to => :worker

  INTERRUPT_SIGNALS = %w[SIGINT SIGTERM].freeze

  SAFE_SLEEP_SECONDS = 60

  def self.start_worker(*args)
    new(*args).start
  end

  def poll_method
    return @poll_method unless @poll_method.nil?

    self.poll_method = worker_settings[:poll_method]&.to_sym
  end

  def poll_method=(val)
    val = "sleep_poll_#{val}"
    raise ArgumentError, _("poll method '%{value}' not defined") % {:value => val} unless respond_to?(val)

    @poll_method = val.to_sym
  end

  def self.corresponding_model
    module_parent
  end

  def initialize(cfg = {})
    @cfg = cfg
    $log ||= Rails.logger

    @server = MiqServer.my_server(true)
    @worker_should_exit = false

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

  def start
    self.class.module_parent.rails_worker? ? start_rails_worker : start_non_rails_worker
  end

  def start_rails_worker
    prepare
    run
  end

  def start_non_rails_worker
    # Create a temp file and immediately unlink it to create a
    # secure hidden file to be used for the child process' stdin.
    #
    # Typically this is done using a pipe but because we are exec'ing
    # the child worker not forking it we aren't able to have the child
    # worker read from one side of the pipe while the parent is writing
    # to the other side.  This means that the amount of data that can be
    # written is limited to the buffer size of the pipe and if you write
    # more than that it will hang.
    stdin_tmp = Tempfile.new
    File.unlink(stdin_tmp.path)

    stdin_tmp.write(worker_options.to_json)
    stdin_tmp.rewind

    $stdin.reopen(stdin_tmp)

    # Using exec here rather than fork+exec so that we can continue to use the
    # standard systemd service Type=notify and not have to use Type=forking which
    # can limit other systemd options available to the service.
    Bundler.unbundled_exec(worker_env, worker_cmdline)
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
    do_before_work_loop
    self
  end

  def run
    do_work_loop
  end

  def self.log_prefix
    @log_prefix ||= "MIQ(#{name})"
  end

  def log_prefix
    self.class.log_prefix
  end

  #
  # @worker object handling methods
  #

  def find_worker_record
    @worker = self.class.corresponding_model.find_by(:guid => @cfg[:guid])
    do_exit("Unable to find instance for worker GUID [#{@cfg[:guid]}].", 1) if @worker.nil?
    MiqWorker.my_guid = @cfg[:guid]
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
    @worker.sd_notify_started if systemd_worker?
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

  def self.safe_log(worker, message = nil, exit_code = 0)
    meth = (exit_code == 0) ? :info : :error

    prefix = "#{log_prefix} "      rescue ""
    pid    = "PID [#{Process.pid}] "    rescue ""
    guid   = worker.nil? ? '' : "GUID [#{worker.guid}] "  rescue ""
    id     = worker.nil? ? '' : "ID [#{worker.id}] "      rescue ""
    logmsg = "#{prefix}#{id}#{pid}#{guid}#{message}"

    begin
      $log.send(meth, logmsg)
    rescue
      puts "#{meth.to_s.upcase}: #{logmsg}" rescue nil
    end
  end

  def safe_log(message = nil, exit_code = 0)
    self.class.safe_log(@worker, message, exit_code)
  end

  def update_worker_record_at_exit(exit_code)
    return if @worker.nil?

    @worker.reload
    @worker.status     = exit_code == 0 ? MiqWorker::STATUS_STOPPED : MiqWorker::STATUS_ABORTED
    @worker.stopped_on = Time.now.utc
    @worker.save

    @worker.sd_notify_stopping if systemd_worker?
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

  def sync_config
    # Sync roles
    @active_roles = MiqServer.my_active_roles(true)
    after_sync_active_roles

    # Sync settings
    Vmdb::Settings.reload!
    @my_zone ||= MiqServer.my_zone
    sync_worker_settings
    after_sync_config

    _log.info("ID [#{@worker.id}], PID [#{Process.pid}], GUID [#{@worker.guid}], Zone [#{@my_zone}], Active Roles [#{@active_roles.join(',')}], Assigned Roles [#{MiqServer.my_role}], Configuration:")
    $log.log_hashes(@worker_settings)
    $log.info("---")
    $log.log_hashes(@cfg)

    @worker.release_db_connection if @worker.respond_to?(:release_db_connection)
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

  def do_work_loop
    warn_about_heartbeat_skipping if skip_heartbeat?
    loop do
      begin
        heartbeat
        do_work
      rescue TemporaryFailure => error
        msg = "#{log_prefix} Temporary failure (message: '#{error}') caught" \
            " during #do_work. Sleeping for a while before resuming."
        _log.warn(msg)
        recover_from_temporary_failure
      rescue SystemExit
        do_exit("SystemExit signal received.")
      rescue Exception => err
        do_exit("An error has occurred during work processing: #{err}\n#{err.backtrace.join("\n")}", 1)
      else
        @backoff = nil
      end

      do_exit("Request to exit received:") if @worker_should_exit

      do_gc
      self.class.log_ruby_object_usage(worker_settings[:top_ruby_object_classes_to_log].to_i)
      send(poll_method)
    end
  end

  def heartbeat
    now = Time.now.utc
    # Heartbeats can be expensive, so do them only when needed
    return if @last_hb.kind_of?(Time) && (@last_hb + worker_settings[:heartbeat_freq]) >= now

    systemd_worker? ? @worker.sd_notify_watchdog : heartbeat_to_file

    if config_out_of_date?
      _log.info("#{log_prefix} Synchronizing configuration...")
      sync_config
      _log.info("#{log_prefix} Synchronizing configuration complete...")
    end

    @last_hb = now
    do_heartbeat_work
  rescue SystemExit, SignalException
    raise
  rescue Exception => err
    do_exit("Error heartbeating because #{err.class.name}: #{err.message}\n#{err.backtrace.join('\n')}", 1)
  end

  def heartbeat_to_file(timeout = nil)
    # Disable heartbeat check.  Useful if a worker is running in isolation
    # without the oversight of MiqServer::WorkerManagement
    return if skip_heartbeat?

    timeout ||= worker_settings[:heartbeat_timeout] || Workers::MiqDefaults.heartbeat_timeout
    File.write(@worker.heartbeat_file, (Time.now.to_i + timeout))
  end

  def config_out_of_date?
    @my_last_config_change ||= Time.now.utc

    last_config_change = server_last_change(:last_config_change)
    if last_config_change && last_config_change > @my_last_config_change
      _log.info("#{log_prefix} Configuration has changed, New TS: #{last_config_change}, Old TS: #{@my_last_config_change}")
      @my_last_config_change = last_config_change
      return true
    end

    false
  end

  def key_store
    @key_store ||= MiqMemcached.client(:namespace => "server_monitor")
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
    ObjectSpace.each_object(Object) do |obj|
      next unless defined?(obj.class)

      types[obj.class.to_s] += 1
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
    INTERRUPT_SIGNALS.each do |signal|
      Kernel.trap(signal) { @worker_should_exit = true }
    end
  end

  protected

  def process_message(message, *args)
    meth = "message_#{message}"
    if respond_to?(meth)
      send(meth, *args)
    else
      _log.warn("#{log_prefix} Message [#{message}] is not recognized, ignoring")
    end
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

  def worker_options
    settings = {
      :worker_settings => worker_settings
    }

    worker.class.worker_settings_paths.to_a.each do |settings_path|
      settings.store_path(settings_path, Settings.to_hash.dig(*settings_path))
    end

    {
      :messaging => MiqQueue.messaging_client_options,
      :settings  => worker.class.normalize_settings!(settings, :recurse => true)
    }
  end

  def worker_env
    {
      "APP_ROOT"              => Rails.root.to_s,
      "GUID"                  => @worker.guid,
      "WORKER_HEARTBEAT_FILE" => @worker.heartbeat_file
    }
  end

  def worker_cmdline
    # Attempt to find the plugin where the class lives then default to
    # the application root
    engine = Vmdb::Plugins.plugin_for_class(self.class) || Rails

    worker_type = self.class.module_parent.name.split("::").last.underscore
    engine.root.join("workers/#{worker_type}/worker").to_s
  end

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
