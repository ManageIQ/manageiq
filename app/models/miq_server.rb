class MiqServer < ApplicationRecord
  include_concern 'WorkerManagement'
  include_concern 'ServerMonitor'
  include_concern 'ServerSmartProxy'
  include_concern 'ConfigurationManagement'
  include_concern 'EnvironmentManagement'
  include_concern 'LogManagement'
  include_concern 'NtpManagement'
  include_concern 'QueueManagement'
  include_concern 'RoleManagement'
  include_concern 'StatusManagement'
  include_concern 'UpdateManagement'
  include_concern 'RhnMirror'

  include UuidMixin
  include MiqPolicyMixin
  acts_as_miq_taggable
  include ReportableMixin
  include RelationshipMixin

  belongs_to              :vm, :inverse_of => :miq_server
  belongs_to              :zone
  has_many                :messages,  :as => :handler, :class_name => 'MiqQueue'
  has_many                :miq_events, :as => :target, :dependent => :destroy

  cattr_accessor          :my_guid_cache

  before_destroy          :validate_is_deleteable

  default_value_for       :rhn_mirror, false

  virtual_column :zone_description, :type => :string

  RUN_AT_STARTUP  = %w( MiqRegion MiqWorker MiqQueue MiqReportResult VmdbTable )

  STATUS_STARTING       = 'starting'.freeze
  STATUS_STARTED        = 'started'.freeze
  STATUS_RESTARTING     = 'restarting'.freeze
  STATUS_STOPPED        = 'stopped'.freeze
  STATUS_QUIESCE        = 'quiesce'.freeze
  STATUS_NOT_RESPONDING = 'not responding'.freeze
  STATUS_KILLED         = 'killed'.freeze

  STATUSES_STOPPED = [STATUS_STOPPED, STATUS_KILLED]
  STATUSES_ACTIVE  = [STATUS_STARTING, STATUS_STARTED]
  STATUSES_ALIVE   = STATUSES_ACTIVE + [STATUS_RESTARTING, STATUS_QUIESCE]

  RESTART_EXIT_STATUS = 123

  def self.active_miq_servers
    where(:status => STATUSES_ACTIVE)
  end

  def self.atStartup
    configuration  = VMDB::Config.new("vmdb")
    starting_roles = configuration.config.fetch_path(:server, :role)

    monitor_class_names.each { |class_name| class_name.constantize.validate_config_settings(configuration) }

    EmsInfra.merge_config_settings(configuration)

    # Change the database role to database_operations
    roles = configuration.config.fetch_path(:server, :role)
    if roles.gsub!(/\bdatabase\b/, 'database_operations')
      configuration.config.store_path(:server, :role, roles)
    end

    roles = configuration.config.fetch_path(:server, :role)
    configuration.save

    # Roles Changed!
    if roles != starting_roles
      # tell the server to pick up the role change
      server = MiqServer.my_server
      server.set_assigned_roles
      server.sync_active_roles
      server.set_active_role_flags
    end

    _log.info("Invoking startup methods")
    begin
      RUN_AT_STARTUP.each do |klass|
        klass = Object.const_get(klass) if klass.class == String
        if klass.respond_to?("atStartup")
          _log.info("Invoking startup method for #{klass}")
          begin
            klass.atStartup
          rescue => err
            _log.log_backtrace(err)
          end
        end
      end
    rescue => err
      _log.log_backtrace(err)
    end
  end

  def self.update_server_config(cfg, key, value)
    if cfg.get(:server, key) != value
      cfg.set(:server, key, value)
      cfg.save
    end
  end

  def starting_server_record
    self.started_on = self.last_heartbeat = Time.now.utc
    self.stopped_on = ""
    self.status     = "starting"
    self.pid        = Process.pid
    self.build      = Vmdb::Appliance.BUILD
    self.version    = Vmdb::Appliance.VERSION
    self.is_master  = false
    self.sql_spid   = ActiveRecord::Base.connection.spid
    save
  end

  def self.setup_data_directory
    # create root data directory
    data_dir = File.join(File.expand_path(Rails.root), "data")
    Dir.mkdir data_dir unless File.exist?(data_dir)
  end

  def self.pidfile
    @pidfile ||= "#{Rails.root}/tmp/pids/evm.pid"
  end

  def self.running?
    p = PidFile.new(pidfile)
    p.running?(/evm_server\.rb/) ? p.pid : false
  end

  def start
    begin
      MiqEvent.raise_evm_event(self, "evm_server_start")
    rescue MiqException::PolicyPreventAction => err
      _log.warn "#{err}"
      # TODO: Need to decide what to do here. Should the cluster be stopped?
      return
    rescue Exception => err
      _log.error "#{err}"
    end

    msg = "Server starting in #{self.class.startup_mode} mode."
    _log.info("#{msg}")
    puts "** #{msg}"

    @vmdb_config = VMDB::Config.new("vmdb")
    starting_server_record

    #############################################################
    # Server Role Assignment
    #
    # 1. Deactivate all roles from last time
    # 2. Set assigned roles from configuration
    # 3. Assert database_owner role - based on vmdb being local
    # 4. Role activation should happen inside monitor_servers
    # 5. Synchronize active roles to monitor for role changes
    #############################################################
    deactivate_all_roles
    set_assigned_roles
    set_database_owner_role(EvmDatabase.local?)
    monitor_servers
    monitor_server_roles if self.is_master?
    sync_active_roles
    set_active_role_flags

    #############################################################
    # Clear the MiqQueue for server and its workers
    #############################################################
    clean_stop_worker_queue_items
    clear_miq_queue_for_this_server

    #############################################################
    # Call all the startup methods only NOW, since some check roles
    #############################################################
    self.class.atStartup

    delete_active_log_collections_queue

    #############################################################
    # Start all the configured workers
    #############################################################
    sync_config
    start_drb_server
    sync_workers
    wait_for_started_workers

    update_attributes(:status => "started")
    _log.info("Server starting complete")
  end

  def self.seed
    unless exists?(:guid => my_guid)
      Zone.seed
      _log.info("Creating Default MiqServer with guid=[#{my_guid}], zone=[#{Zone.default_zone.name}]")
      create!(:guid => my_guid, :zone => Zone.default_zone)
      my_server_clear_cache
      _log.info("Creating Default MiqServer... Complete")
    end
    my_server
  end

  def self.start
    validate_database

    EvmDatabase.seed_primordial

    setup_data_directory
    cfg = activate_configuration

    svr = my_server(true)
    svr_hash = {}

    ipaddr, hostname, mac_address = get_network_information

    if ipaddr =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
      svr_hash[:ipaddress] = ipaddr
      update_server_config(cfg, :host, ipaddr)
    end

    unless hostname.blank?
      svr_hash[:hostname] = hostname
      update_server_config(cfg, :hostname, hostname)
    end

    unless mac_address.blank?
      svr_hash[:mac_address] = mac_address
    end

    # Determine the corresponding Vm
    if svr.vm_id.nil?
      vms = Vm.find_all_by_mac_address_and_hostname_and_ipaddress(mac_address, hostname, ipaddr)
      if vms.length > 1
        _log.warn "Found multiple Vms that may represent this MiqServer: #{vms.collect(&:id).sort.inspect}"
      elsif vms.length == 1
        svr_hash[:vm_id] = vms.first.id
      end
    end

    unless svr.new_record?
      [
        # Reset the DRb URI
        :drb_uri, :last_heartbeat,
        # Reset stats
        :memory_usage, :memory_size, :percent_memory, :percent_cpu, :cpu_time
      ].each { |k| svr_hash[k] = nil }
    end

    svr.update_attributes(svr_hash)
    my_server_clear_cache

    _log.info("Server IP Address: #{svr.ipaddress}")    unless svr.ipaddress.blank?
    _log.info("Server Hostname: #{svr.hostname}")       unless svr.hostname.blank?
    _log.info("Server MAC Address: #{svr.mac_address}") unless svr.mac_address.blank?
    _log.info "Server GUID: #{my_guid}"
    _log.info "Server Zone: #{my_zone}"
    _log.info "Server Role: #{my_role}"
    region = MiqRegion.my_region
    _log.info "Server Region number: #{region.region}, name: #{region.name}" unless region.nil?
    _log.info "Database Latency: #{EvmDatabase.ping(connection)} ms"

    Vmdb::Appliance.log_config_on_startup

    svr.ntp_reload(svr.server_ntp_settings)
    # Update the config settings in the db table for MiqServer
    svr.config_updated(OpenStruct.new(:name => cfg.get(:server, :name)))

    EvmDatabase.seed_last

    start_memcached(cfg)
    prep_apache_proxying
    svr.start
    svr.monitor_loop
  end

  def validate_is_deleteable
    unless self.is_deleteable?
      msg = @error_message
      @error_message = nil
      _log.error("#{msg}")
      raise _(msg)
    end
  end

  def heartbeat
    # Heartbeat the server
    t = Time.now.utc
    _log.info("Heartbeat [#{t}]...")
    reload
    self.last_heartbeat = t
    self.status = "started" if status == "not responding"
    save
    _log.info("Heartbeat [#{t}]...Complete")
  end

  def log_active_servers
    MiqRegion.my_region.active_miq_servers.sort_by { |s| [s.my_zone, s.name] }.each do |s|
      local  = s.is_local? ? 'Y' : 'N'
      master = s.is_master? ? 'Y' : 'N'
      $log.info "MiqServer: local=#{local}, master=#{master}, status=#{'%08s' % s.status}, id=#{'%05d' % s.id}, pid=#{'%05d' % s.pid}, guid=#{s.guid}, name=#{s.name}, zone=#{s.my_zone}, hostname=#{s.hostname}, ipaddress=#{s.ipaddress}, version=#{s.version}, build=#{s.build}, active roles=#{s.active_role_names.join(':')}"
    end
  end

  def monitor_poll
    ((@vmdb_config && @vmdb_config.config[:server][:monitor_poll]) || 5.seconds).to_i_with_method
  end

  def stop_poll
    ((@vmdb_config && @vmdb_config.config[:server][:stop_poll]) || 10.seconds).to_i_with_method
  end

  def heartbeat_frequency
    ((@vmdb_config && @vmdb_config.config[:server][:heartbeat_frequency]) || 30.seconds).to_i_with_method
  end

  def server_dequeue_frequency
    ((@vmdb_config && @vmdb_config.config[:server][:server_dequeue_frequency]) || 5.seconds).to_i_with_method
  end

  def server_monitor_frequency
    ((@vmdb_config && @vmdb_config.config[:server][:server_monitor_frequency]) || 60.seconds).to_i_with_method
  end

  def server_log_frequency
    ((@vmdb_config && @vmdb_config.config[:server][:server_log_frequency]) || 5.minutes).to_i_with_method
  end

  def server_log_timings_threshold
    ((@vmdb_config && @vmdb_config.config[:server][:server_log_timings_threshold]) || 1.second).to_i_with_method
  end

  def worker_dequeue_frequency
    ((@vmdb_config && @vmdb_config.config[:server][:worker_dequeue_frequency]) || 3.seconds).to_i_with_method
  end

  def worker_messaging_frequency
    ((@vmdb_config && @vmdb_config.config[:server][:worker_messaging_frequency]) || 5.seconds).to_i_with_method
  end

  def worker_monitor_frequency
    ((@vmdb_config && @vmdb_config.config[:server][:worker_monitor_frequency]) || 15.seconds).to_i_with_method
  end

  def threshold_exceeded?(name, now = Time.now.utc)
    @thresholds ||= Hash.new(1.day.ago.utc)
    exceeded = now > (@thresholds[name] + send(name))
    @thresholds[name] = now if exceeded
    exceeded
  end

  def monitor
    now = Time.now.utc
    Benchmark.realtime_block(:heartbeat)               { heartbeat }                        if threshold_exceeded?(:heartbeat_frequency, now)
    Benchmark.realtime_block(:server_dequeue)          { process_miq_queue }                if threshold_exceeded?(:server_dequeue_frequency, now)

    Benchmark.realtime_block(:server_monitor) do
      monitor_servers
      monitor_server_roles if self.is_master?
    end if threshold_exceeded?(:server_monitor_frequency, now)

    Benchmark.realtime_block(:log_active_servers)      { log_active_servers }               if threshold_exceeded?(:server_log_frequency, now)
    Benchmark.realtime_block(:worker_monitor)          { monitor_workers }                  if threshold_exceeded?(:worker_monitor_frequency, now)
    Benchmark.realtime_block(:worker_dequeue)          { populate_queue_messages }          if threshold_exceeded?(:worker_dequeue_frequency, now)
  rescue SystemExit
    raise
  rescue Exception => err
    _log.error("#{err.message}")
    _log.log_backtrace(err)

    begin
      _log.info("Reconnecting to database after error...")
      ActiveRecord::Base.connection.reconnect!
    rescue Exception => err
      _log.error("#{err.message}, during reconnect!")
    else
      _log.info("Reconnecting to database after error...Successful")
    end
  end

  def monitor_loop
    loop do
      _dummy, timings = Benchmark.realtime_block(:total_time) { monitor }
      _log.info "Server Monitoring Complete - Timings: #{timings.inspect}" unless timings[:total_time] < server_log_timings_threshold
      sleep monitor_poll
    end
  end

  def stop(sync = false)
    return if self.stopped?

    shutdown_and_exit_queue
    wait_for_stopped if sync
  rescue Exception => err
    _log.error "#{err}"
  end

  def wait_for_stopped
    loop do
      reload
      break if self.stopped?
      sleep stop_poll
    end
  end

  def self.stop(sync = false)
    svr = my_server(true) rescue nil
    svr.stop(sync) unless svr.nil?
    PidFile.new(pidfile).remove
  end

  def kill
    # Kill all the workers of this server
    kill_all_workers

    # Then kill this server
    _log.info("initiated for #{format_full_log_msg}")
    update_attributes(:stopped_on => Time.now.utc, :status => "killed", :is_master => false)
    (pid == Process.pid) ? shutdown_and_exit : Process.kill(9, pid)
  rescue SystemExit
    raise
  rescue Exception => err
    _log.error "#{err}"
  end

  def self.kill
    svr = my_server(true)
    svr.kill unless svr.nil?
    PidFile.new(pidfile).remove
  end

  def shutdown
    _log.info("initiated for #{format_full_log_msg}")
    begin
      MiqEvent.raise_evm_event(self, "evm_server_stop")
    rescue MiqException::PolicyPreventAction => err
      _log.warn "#{err}"
      return
    rescue Exception => err
      _log.error "#{err}"
    end

    quiesce
  end

  def shutdown_and_exit(exit_status = 0)
    shutdown
    exit exit_status
  end

  def quiesce
    update_attribute(:status, 'quiesce')
    begin
      deactivate_all_roles
      quiesce_all_workers
      update_attributes(:stopped_on => Time.now.utc, :status => "stopped", :is_master => false)
    rescue => err
      puts "#{err}"
      puts "#{err.backtrace.join("\n")}"
    end
  end

  # Restart the local server
  def restart
    raise _("Server restart is only supported on Linux") unless MiqEnvironment::Command.is_linux?

    _log.info("Server restart initiating...")
    update_attribute(:status, "restarting")

    shutdown_and_exit(RESTART_EXIT_STATUS)
  end

  def format_full_log_msg
    "MiqServer [#{name}] with ID: [#{id}], PID: [#{pid}], GUID: [#{guid}]"
  end

  def format_short_log_msg
    "MiqServer [#{name}] with ID: [#{id}]"
  end

  def friendly_name
    _("EVM Server (%{id})") % {:id => pid}
  end

  def who_am_i
    @who_am_i ||= "#{name} #{my_zone} #{self.class.name} #{id}"
  end

  def is_local?
    guid == MiqServer.my_guid
  end

  def is_remote?
    !is_local?
  end

  def is_recently_active?
    last_heartbeat && (last_heartbeat >= 10.minutes.ago.utc)
  end

  def is_deleteable?
    if self.is_local?
      @error_message = N_("Cannot delete currently used %{log_message}") % {:log_message => format_short_log_msg}
      return false
    end
    return true if self.stopped?

    if is_recently_active?
      @error_message = N_("Cannot delete recently active %{log_message}") % {:log_message => format_short_log_msg}
      return false
    end

    true
  end

  def state
    "on"
  end

  def started?
    status == "started"
  end

  def stopped?
    STATUSES_STOPPED.include?(status)
  end

  def active?
    STATUSES_ACTIVE.include?(status)
  end

  def alive?
    STATUSES_ALIVE.include?(status)
  end

  def logon_status
    return :ready if self.started?
    started_on < (Time.now.utc - get_config("vmdb").config[:server][:startup_timeout]) ? :timed_out_starting : status.to_sym
  end

  def logon_status_details
    result = {:status => logon_status}
    return result if result[:status] == :ready

    wcnt = MiqWorker.find_starting.length
    workers = wcnt == 1 ? "worker" : "workers"
    message = "Waiting for #{wcnt} #{workers} to start"
    result.merge(:message => message)
  end

  def self.config_updated
    cfg = VMDB::Config.new("vmdb")
    cfg.save
  end

  def config_updated(data, _mode = "activate")
    # Check that the column exists in the table and we are passed data that does not match
    # the current vaule.  The first check allows this code to run if we migrate down then
    # back up again.
    if self.respond_to?(:name) && data.name && name != data.name
      self.name = data.name
    end

    unless data.zone.nil?
      self.zone = Zone.find_by(:name => data.zone)
      save
    end
    update_capabilities

    save
  end

  #
  # Zone and Role methods
  #
  def self.my_guid
    @@my_guid_cache ||= begin
      guid_file = Rails.root.join("GUID")
      File.write(guid_file, MiqUUID.new_guid) unless File.exist?(guid_file)
      File.read(guid_file).strip
    end
  end

  cache_with_timeout(:my_server) { find_by(:guid => my_guid) }

  def self.my_zone(force_reload = false)
    my_server(force_reload).my_zone
  end

  def zone_description
    zone ? zone.description : nil
  end

  def self.my_roles(force_reload = false)
    my_server(force_reload).my_roles
  end

  def self.my_role(force_reload = false)
    my_server(force_reload).my_role
  end

  def self.my_active_roles(force_reload = false)
    my_server(force_reload).active_role_names
  end

  def self.my_active_role(force_reload = false)
    my_server(force_reload).active_role
  end

  def self.licensed_roles(force_reload = false)
    my_server(force_reload).licensed_roles
  end

  def my_zone
    zone.name
  end

  def has_zone?(zone_name)
    my_zone == zone_name
  end

  CONDITION_CURRENT = {:status => ["starting", "started"]}
  def self.find_started_in_my_region
    in_my_region.where(CONDITION_CURRENT)
  end

  def self.find_all_started_servers
    where(CONDITION_CURRENT)
  end

  def find_other_started_servers_in_region
    MiqRegion.my_region.active_miq_servers.to_a.delete_if { |s| s.id == id }
  end

  def find_other_servers_in_region
    MiqRegion.my_region.miq_servers.to_a.delete_if { |s| s.id == id }
  end

  def find_other_started_servers_in_zone
    zone.active_miq_servers.to_a.delete_if { |s| s.id == id }
  end

  def find_other_servers_in_zone
    zone.miq_servers.to_a.delete_if { |s| s.id == id }
  end

  def log_prefix
    @log_prefix ||= "MIQ(#{self.class.name})"
  end

  def display_name
    "#{name} [#{id}]"
  end

  def server_timezone
    get_config("vmdb").config.fetch_path(:server, :timezone) || "UTC"
  end

  def tenant_identity
    User.super_admin
  end
end # class MiqServer
