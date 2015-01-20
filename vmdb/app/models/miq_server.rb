class MiqServer < ActiveRecord::Base
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

  belongs_to              :vm
  belongs_to              :zone
  has_many                :messages,  :as => :handler, :class_name => 'MiqQueue'
  has_and_belongs_to_many :product_updates
  has_many                :miq_groups, :as => :resource

  cattr_accessor          :my_guid_cache

  after_create            :sync_admin_password_queue
  before_destroy          :validate_is_deleteable

  default_value_for       :rhn_mirror, false

  virtual_column :zone_description, :type => :string

  RUN_AT_STARTUP  = %w{ MiqRegion MiqWorker MiqQueue MiqReportResult VmdbTable }

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

  def self.active_miq_servers
    where(:status => STATUSES_ACTIVE)
  end

  def self.atStartup
    log_prefix = "MIQ(MiqServer.atStartup)"

    configuration  = VMDB::Config.new("vmdb")
    starting_roles = configuration.config.fetch_path(:server, :role)

    monitor_class_names.each { |class_name| class_name.constantize.validate_config_settings(configuration)}

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

    $log.info("#{log_prefix} Invoking startup methods")
    begin
      RUN_AT_STARTUP.each do |klass|
        klass = Object.const_get(klass) if klass.class == String
        if klass.respond_to?("atStartup")
          $log.info("#{log_prefix} Invoking startup method for #{klass}")
          begin
            klass.atStartup
          rescue => err
            $log.log_backtrace(err)
          end
        end
      end
    rescue => err
      $log.log_backtrace(err)
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
    self.save
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
    p = PidFile.new(self.pidfile)
    p.running?(/evm_server\.rb/) ? p.pid : false
  end

  def start
    log_prefix = "MIQ(MiqServer.start)"

    begin
      MiqEvent.raise_evm_event(self, "evm_server_start")
    rescue MiqException::PolicyPreventAction => err
      $log.warn "#{log_prefix} #{err}"
      # TODO: Need to decide what to do here. Should the cluster be stopped?
      return
    rescue Exception => err
      $log.error "#{log_prefix} #{err}"
    end

    msg = "Server starting in #{self.class.startup_mode} mode."
    $log.info("#{log_prefix} #{msg}")
    puts "** #{msg}"

    @vmdb_config = VMDB::Config.new("vmdb")
    self.starting_server_record

    #############################################################
    # Server Role Assignment
    #
    # 1. Deactivate all roles from last time
    # 2. Set assigned roles from configuration
    # 3. Assert database_owner role - based on vmdb being local
    # 4. Role activation should happen inside monitor_servers
    # 5. Synchronize active roles to monitor for role changes
    #############################################################
    self.deactivate_all_roles
    self.set_assigned_roles
    self.set_database_owner_role(EvmDatabase.local?)
    self.monitor_servers
    self.monitor_server_roles if self.is_master?
    self.sync_active_roles
    self.set_active_role_flags

    #############################################################
    # Clear the MiqQueue for server and its workers
    #############################################################
    self.clean_stop_worker_queue_items
    self.clear_miq_queue_for_this_server

    #############################################################
    # Call all the startup methods only NOW, since some check roles
    #############################################################
    self.class.atStartup

    self.delete_active_log_collections_queue

    #############################################################
    # Start all the configured workers
    #############################################################
    self.sync_config
    self.start_drb_server
    self.sync_workers
    self.wait_for_started_workers

    self.update_attributes(:status => "started")
  end

  def self.seed
    MiqRegion.my_region.lock do
      unless self.exists?(:guid => self.my_guid)
        $log.info("MIQ(MiqServer.seed) Creating Default MiqServer with guid=[#{self.my_guid}], zone=[#{Zone.default_zone.name}]")
        self.create!(:guid => self.my_guid, :zone => Zone.default_zone)
        self.my_server_clear_cache
        $log.info("MIQ(MiqServer.seed) Creating Default MiqServer... Complete")
      end
      self.my_server
    end
  end

  def self.start
    log_prefix = "MIQ(MiqServer.start)"

    self.validate_database

    EvmDatabase.seed_primordial

    self.setup_data_directory
    cfg = self.activate_configuration

    svr = self.my_server(true)
    svr_hash = {}

    ipaddr, hostname, mac_address = self.get_network_information

    if ipaddr =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
      svr_hash[:ipaddress] = ipaddr
      self.update_server_config(cfg, :host, ipaddr)
    end

    unless hostname.empty?
      svr_hash[:hostname] = hostname
      self.update_server_config(cfg, :hostname, hostname)
    end

    unless mac_address.empty?
      svr_hash[:mac_address] = mac_address
    end

    # Determine the corresponding Vm
    if svr.vm_id.nil?
      vms = Vm.find_all_by_mac_address_and_hostname_and_ipaddress(mac_address, hostname, ipaddr)
      if vms.length > 1
        $log.warn "Found multiple Vms that may represent this MiqServer: #{vms.collect(&:id).sort.inspect}"
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
    self.my_server_clear_cache

    $log.info("#{log_prefix} Server IP Address: #{svr.ipaddress}")    unless svr.ipaddress.blank?
    $log.info("#{log_prefix} Server Hostname: #{svr.hostname}")       unless svr.hostname.blank?
    $log.info("#{log_prefix} Server MAC Address: #{svr.mac_address}") unless svr.mac_address.blank?
    $log.info "#{log_prefix} Server GUID: #{self.my_guid}"
    $log.info "#{log_prefix} Server Zone: #{self.my_zone}"
    $log.info "#{log_prefix} Server Role: #{self.my_role}"
    region = MiqRegion.my_region
    $log.info "#{log_prefix} Server Region number: #{region.region}, name: #{region.name}" unless region.nil?
    $log.info "#{log_prefix} Database Latency: #{self.db_ping} ms"

    Vmdb::Appliance.log_config_on_startup

    ProductUpdate.server_link_to_current_update(svr)

    svr.ntp_reload(svr.server_ntp_settings)
    # Update the config settings in the db table for MiqServer
    svr.config_updated(OpenStruct.new(:name => cfg.get(:server, :name)))

    EvmDatabase.seed_last

    self.start_memcached(cfg)
    self.prep_apache_proxying
    svr.start
    svr.monitor_loop
  end

  def validate_is_deleteable
    unless self.is_deleteable?
      msg = @error_message
      @error_message = nil
      $log.error("MIQ(#{self.class.name}.before_destroy) #{msg}")
      raise msg
    end
  end

  def sync_admin_password_queue
    MiqQueue.put_unless_exists(
      :class_name  => "User",
      :method_name => "sync_admin_password",
      :server_guid => self.guid,
      :zone        => self.zone.name,
      :priority    => MiqQueue::HIGH_PRIORITY
    )
  end

  def heartbeat
    log_prefix = "MIQ(MiqServer.heartbeat)"

    # Heartbeat the server
    t = Time.now.utc
    $log.info("#{log_prefix} Heartbeat [#{t}]...")
    self.reload
    self.last_heartbeat = t
    self.status = "started" if self.status == "not responding"
    self.save
    $log.info("#{log_prefix} Heartbeat [#{t}]...Complete")
  end

  def log_active_servers
    MiqRegion.my_region.active_miq_servers.sort_by { |s| [ s.my_zone, s.name ] }.each do |s|
      local  = s.is_local?  ? 'Y' : 'N'
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
    exceeded = now > (@thresholds[name] + self.send(name))
    @thresholds[name] = now if exceeded
    exceeded
  end

  def monitor
    begin
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
      log_prefix = "MIQ(MiqServer.monitor)"
      $log.error("#{log_prefix} #{err.message}")
      $log.log_backtrace(err)

      begin
        $log.info("#{log_prefix} Reconnecting to database after error...")
        ActiveRecord::Base.connection.reconnect!
      rescue Exception => err
        $log.error("#{log_prefix} #{err.message}, during reconnect!")
      else
        $log.info("#{log_prefix} Reconnecting to database after error...Successful")
      end
    end
  end

  def monitor_loop
    log_prefix = "MIQ(MiqServer.monitor_loop)"

    loop do
      dummy, timings = Benchmark.realtime_block(:total_time) { self.monitor }
      $log.info "#{log_prefix} Server Monitoring Complete - Timings: #{timings.inspect}" unless timings[:total_time] < server_log_timings_threshold
      sleep monitor_poll
    end
  end

  def stop(sync = false)
    log_prefix = "MIQ(MiqServer.stop)"
    begin
      return if self.stopped?

      self.shutdown_and_exit_queue
      self.wait_for_stopped if sync
    rescue Exception => err
      $log.error "#{log_prefix} #{err}"
    end
  end

  def wait_for_stopped
    loop do
      self.reload
      break if self.stopped?
      sleep stop_poll
    end
  end

  def self.stop(sync = false)
    svr = self.my_server(true) rescue nil
    svr.stop(sync) unless svr.nil?
    PidFile.new(self.pidfile).remove
  end

  def kill
    log_prefix = "MIQ(MiqServer.kill)"
    begin
      # Kill all the workers of this server
      self.kill_all_workers

      # Then kill this server
      $log.info("#{log_prefix} initiated for #{format_full_log_msg}")
      self.update_attributes(:stopped_on => Time.now.utc, :status => "killed", :is_master => false)
      (self.pid == Process.pid) ? self.shutdown_and_exit : Process.kill(9, self.pid)
    rescue SystemExit
      raise
    rescue Exception => err
      $log.error "#{log_prefix} #{err}"
    end
  end

  def self.kill
    svr = self.my_server(true)
    svr.kill unless svr.nil?
    PidFile.new(self.pidfile).remove
  end

  def shutdown
    log_prefix = "MIQ(MiqServer.shutdown)"
    $log.info("#{log_prefix} initiated for #{format_full_log_msg}")
    begin
      MiqEvent.raise_evm_event(self, "evm_server_stop")
    rescue MiqException::PolicyPreventAction => err
      $log.warn "#{log_prefix} #{err}"
      return
    rescue Exception => err
      $log.error "#{log_prefix} #{err}"
    end

    self.quiesce
  end

  def shutdown_and_exit
    self.shutdown
    exit
  end

  def quiesce
    self.update_attribute(:status, 'quiesce')
    begin
      self.deactivate_all_roles
      self.quiesce_all_workers
      self.update_attributes(:stopped_on => Time.now.utc, :status => "stopped", :is_master => false)
    rescue => err
      puts "#{err}"
      puts "#{err.backtrace.join("\n")}"
    end
  end

  def reset
    # TODO: Need to handle calling this during startup because it results in starting generic workers from the main process
    # MiqGenericWorker.update_config
    # XXX

    # When the vmdb is reset, need to check the ntp settings, and apply them
    self.ntp_reload_queue
  end

  # Restart the local server
  def restart
    log_prefix = "MIQ(MiqServer#restart)"
    raise "Server reset is only supported on Linux" unless MiqEnvironment::Command.is_linux?

    $log.info("#{log_prefix} Server restart initiating...")
    self.update_attribute(:status, "restarting")

    $log.info("#{log_prefix} Server shutting down...")
    self.class.stop

    logfile = File.expand_path(File.join(Rails.root, "log/vmdb_restart.log"))
    File.delete(logfile) if File.exist?(logfile)

    restart_script = File.join(Rails.root, "vmdb_restart")
    File.chmod(0755, restart_script)

    cmd = "#{restart_script} 2>&1 >> #{logfile}"
    pid = spawn("nohup", restart_script, [:out, :err] => [logfile, "a"])
    Process.detach(pid)
  end

  def format_full_log_msg
    "MiqServer [#{self.name}] with ID: [#{self.id}], PID: [#{self.pid}], GUID: [#{self.guid}]"
  end

  def format_short_log_msg
    "MiqServer [#{self.name}] with ID: [#{self.id}]"
  end

  def friendly_name
    "EVM Server (#{self.pid})"
  end

  def who_am_i
    @who_am_i ||= "#{self.name} #{self.my_zone} #{self.class.name} #{self.id}"
  end

  def is_local?
    self.guid == MiqServer.my_guid
  end

  def is_remote?
    !is_local?
  end

  def is_recently_active?
    self.last_heartbeat && (self.last_heartbeat >= 10.minutes.ago.utc)
  end

  def is_deleteable?
    if self.is_local?
      @error_message = "Cannot delete currently used #{format_short_log_msg}"
      return false
    end
    return true if self.stopped?

    if is_recently_active?
      @error_message = "Cannot delete recently active #{format_short_log_msg}"
      return false
    end

    return true
  end

  def state
    "on"
  end

  def started?
    self.status == "started"
  end

  def stopped?
    STATUSES_STOPPED.include?(self.status)
  end

  def active?
    STATUSES_ACTIVE.include?(status)
  end

  def alive?
    STATUSES_ALIVE.include?(self.status)
  end

  def logon_status
    return :ready if self.started?
    return self.started_on < (Time.now.utc - get_config("vmdb").config[:server][:startup_timeout]) ? :timed_out_starting : self.status.to_sym
  end

  def logon_status_details
    result = {:status => self.logon_status}
    return result if result[:status] == :ready

    wcnt = MiqWorker.find_starting.length
    workers = wcnt == 1 ? "worker" : "workers"
    message = "Waiting for #{wcnt} #{workers} to start"
    return result.merge(:message => message)
  end

  def self.config_updated
    cfg = VMDB::Config.new("vmdb")
    cfg.save
  end

  def config_updated(data, mode="activate")
    # Check that the column exists in the table and we are passed data that does not match
    # the current vaule.  The first check allows this code to run if we migrate down then
    # back up again.
    if self.respond_to?(:name) && data.name && self.name != data.name
      self.name = data.name
    end

    unless data.zone.nil?
      self.zone = Zone.where(:name => data.zone).first
      self.save
    end
    self.update_capabilities

    self.save
  end

  #
  # Zone and Role methods
  #
  def self.my_guid
    @@my_guid_cache ||= begin
      guid_file = File.join(File.expand_path(Rails.root), "GUID")
      unless File.exist?(guid_file)
        new_guid = MiqUUID.new_guid
        File.open(guid_file, "w") {|f| f.write(new_guid)}
      end
      File.read(guid_file).strip
    end
  end

  cache_with_timeout(:my_server) { self.where(:guid => self.my_guid).first }

  def self.my_zone(force_reload = false)
    self.my_server(force_reload).my_zone
  end

  def zone_description
    self.zone ? self.zone.description : nil
  end

  def self.my_roles(force_reload = false)
    self.my_server(force_reload).my_roles
  end

  def self.my_role(force_reload = false)
    self.my_server(force_reload).my_role
  end

  def self.my_active_roles(force_reload = false)
    self.my_server(force_reload).active_role_names
  end

  def self.my_active_role(force_reload = false)
    self.my_server(force_reload).active_role
  end

  def self.licensed_roles(force_reload = false)
    self.my_server(force_reload).licensed_roles
  end

  def my_zone
    self.zone.name
  end

  def has_zone?(zone_name)
    self.my_zone == zone_name
  end

  CONDITION_CURRENT = {:status => ["starting", "started"]}
  def self.find_started_in_my_region
    self.in_my_region.where(CONDITION_CURRENT)
  end

  def self.find_all_started_servers
    self.where(CONDITION_CURRENT)
  end

  def find_other_started_servers_in_region
    MiqRegion.my_region.active_miq_servers.to_a.delete_if { |s| s.id == self.id }
  end

  def find_other_servers_in_region
    MiqRegion.my_region.miq_servers.to_a.delete_if { |s| s.id == self.id }
  end

  def find_other_started_servers_in_zone
    self.zone.active_miq_servers.to_a.delete_if { |s| s.id == self.id }
  end

  def find_other_servers_in_zone
    self.zone.miq_servers.to_a.delete_if { |s| s.id == self.id }
  end

  # Determines the average time to the database in milliseconds
  def self.db_ping
    EvmDatabase.ping(self.connection)
  end

  def log_prefix
    @log_prefix ||= "MIQ(#{self.class.name})"
  end

  def display_name
    "#{name} [#{id}]"
  end
end #class MiqServer
