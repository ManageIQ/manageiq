require 'miq-process'
require 'pid_file'

class EvmServer
  include Vmdb::Logging

  SERVER_PROCESS_TITLE = 'MIQ Server'.freeze

  attr_accessor :servers_to_monitor

  def initialize
    $log ||= Rails.logger
    @servers_to_monitor = servers_from_db
  end

  def start
    if pid = MiqServer.running?
      $log.warn("EVM is already running (PID=#{pid})")
      exit
    end

    PidFile.create(MiqServer.pidfile)
    set_process_title
    validate_database
    EvmDatabase.seed_primordial
    check_migrations_up_to_date

    start_servers
    monitor_servers
  rescue Interrupt => e
    _log.info("Received #{e.message} signal, killing server")
    kill_servers
    exit 1
  rescue SignalException => e
    _log.info("Received #{e.message} signal, shutting down server")
    stop_servers
    exit 0
  end

  def start_servers
    for_each_server { start_server }
  end

  def monitor_servers
    loop do
      refresh_servers_to_monitor
      for_each_server { monitor }
      sleep ::Settings.server.monitor_poll.to_i_with_method
    end
  end

  def stop_servers
    for_each_server { @server.shutdown }
  end

  def kill_servers
    for_each_server do
      @server.kill_all_workers
      @server.update(:stopped_on => Time.now.utc, :status => "killed", :is_master => false)
    end
  end

  def refresh_servers_to_monitor
    # Add the server object to our list if we're not monitoring it already
    servers_from_db.each do |db_server|
      servers_to_monitor << db_server unless monitoring_server?(db_server)
    end

    # Remove and shutdown a server if we're monitoring it and it is no longer in the database
    servers_to_monitor.delete_if do |monitor_server|
      servers_from_db.none? { |db_server| db_server.id == monitor_server.id }.tap do |should_delete|
        monitor_server.shutdown if should_delete
      end
    end
  end

  def self.start(*args)
    new.start
  end

  private

  def monitoring_server?(server)
    servers_to_monitor.any? do |monitor_server|
      monitor_server.id == server.id
    end
  end

  def servers_from_db
    MiqEnvironment::Command.is_podified? ? MiqServer.all.to_a : [MiqServer.my_server(true)]
  end

  def set_process_title
    Process.setproctitle(SERVER_PROCESS_TITLE) if Process.respond_to?(:setproctitle)
  end

  def start_server
    Vmdb::Settings.activate

    save_local_network_info
    set_local_server_vm
    reset_server_runtime_info
    log_server_info

    Vmdb::Appliance.log_config_on_startup

    @server.ntp_reload
    @server.set_database_application_name

    EvmDatabase.seed_rest

    MiqServer.start_memcached
    MiqApache::Control.restart if MiqEnvironment::Command.supports_apache?

    MiqEvent.raise_evm_event(@server, "evm_server_start")

    msg = "Server starting in #{MiqServer.startup_mode} mode."
    _log.info(msg)
    puts "** #{msg}"

    @server.starting_server_record

    configure_server_roles
    clear_queue

    MiqServer.log_managed_entities
    MiqServer.clean_all_workers
    MiqServer.clean_dequeued_messages
    MiqServer.purge_report_results

    @server.delete_active_log_collections_queue

    start_workers

    @server.update(:status => "started")
    _log.info("Server starting complete")
  end

  def monitor
    _dummy, timings = Benchmark.realtime_block(:total_time) { @server.monitor }
    _log.info("Server Monitoring Complete - Timings: #{timings.inspect}") unless timings[:total_time] < ::Settings.server.server_log_timings_threshold.to_i_with_method
  end

  def validate_database
    # Remove the connection and establish a new one since reconnect! doesn't always play nice with SSL postgresql connections
    spec_name = ActiveRecord::Base.connection_specification_name
    ActiveRecord::Base.establish_connection(ActiveRecord::Base.remove_connection(spec_name))

    # Log the Versions
    _log.info("Database Adapter: [#{ActiveRecord::Base.connection.adapter_name}], version: [#{ActiveRecord::Base.connection.database_version}]")                   if ActiveRecord::Base.connection.respond_to?(:database_version)
    _log.info("Database Adapter: [#{ActiveRecord::Base.connection.adapter_name}], detailed version: [#{ActiveRecord::Base.connection.detailed_database_version}]") if ActiveRecord::Base.connection.respond_to?(:detailed_database_version)
  end

  def check_migrations_up_to_date
    up_to_date, *message = SchemaMigration.up_to_date?
    level = up_to_date ? :info : :warn
    message.to_miq_a.each { |msg| _log.send(level, msg) }
    up_to_date
  end

  def save_local_network_info
    server_hash = {}
    config_hash = {}

    ipaddr, hostname, mac_address = MiqServer.get_network_information

    if ipaddr =~ Regexp.union(Resolv::IPv4::Regex, Resolv::IPv6::Regex).freeze
      server_hash[:ipaddress] = config_hash[:host] = ipaddr
    end

    if hostname.present? && hostname.hostname?
      hostname = nil if hostname =~ /.*localhost.*/
      server_hash[:hostname] = config_hash[:hostname] = hostname
    end

    unless mac_address.blank?
      server_hash[:mac_address] = mac_address
    end

    if config_hash.any?
      Vmdb::Settings.save!(@server, :server => config_hash)
      ::Settings.reload!
    end

    @server.update(server_hash)
  end

  def set_local_server_vm
    if @server.vm_id.nil?
      vms = Vm.find_all_by_mac_address_and_hostname_and_ipaddress(@server.mac_address, @server.hostname, @server.ipaddress)
      if vms.length > 1
        _log.warn("Found multiple Vms that may represent this MiqServer: #{vms.collect(&:id).sort.inspect}")
      elsif vms.length == 1
        @server.update(:vm_id => vms.first.id)
      end
    end
  end

  def reset_server_runtime_info
    @server.update(
      :drb_uri        => nil,
      :last_heartbeat => nil,
      :memory_usage   => nil,
      :memory_size    => nil,
      :percent_memory => nil,
      :percent_cpu    => nil,
      :cpu_time       => nil
    )
  end

  def log_server_info
    _log.info("Server IP Address: #{@server.ipaddress}")    unless @server.ipaddress.blank?
    _log.info("Server Hostname: #{@server.hostname}")       unless @server.hostname.blank?
    _log.info("Server MAC Address: #{@server.mac_address}") unless @server.mac_address.blank?
    _log.info("Server GUID: #{MiqServer.my_guid}")
    _log.info("Server Zone: #{MiqServer.my_zone}")
    _log.info("Server Role: #{MiqServer.my_role}")
    region = MiqRegion.my_region
    _log.info("Server Region number: #{region.region}, name: #{region.name}") unless region.nil?
    _log.info("Database Latency: #{EvmDatabase.ping(ApplicationRecord.connection)} ms")
  end

  def configure_server_roles
    @server.ensure_default_roles

    #############################################################
    # Server Role Assignment
    #
    # - Deactivate all roles from last time
    # - Assert database_owner role - based on vmdb being local
    # - Role activation should happen inside monitor_servers
    # - Synchronize active roles to monitor for role changes
    #############################################################
    @server.deactivate_all_roles
    @server.set_database_owner_role(EvmDatabase.local?)
    @server.monitor_servers
    @server.monitor_server_roles if @server.is_master?
    @server.sync_active_roles
    @server.set_active_role_flags
  end

  def clear_queue
    #############################################################
    # Clear the MiqQueue for server and its workers
    #############################################################
    @server.clean_stop_worker_queue_items
    @server.clear_miq_queue_for_this_server
  end

  def start_workers
    #############################################################
    # Start all the configured workers
    #############################################################
    @server.clean_heartbeat_files
    @server.sync_config
    @server.start_drb_server
    @server.sync_workers
    @server.wait_for_started_workers
  end

  ######################################################################
  # Warning:
  #
  # The following methods can lead to unexpected (and likely unpleasant)
  # behavior if used out of the scope of the orchestrator process.
  #
  # They change the global state which is used to determine the current
  # server's identity. This intentionally will alter the values of calls
  # such as MiqServer.my_server and MiqServer.my_guid, and also the
  # contents of the global ::Settings constant.
  ######################################################################
  def for_each_server
    servers_to_monitor.each do |s|
      impersonate_server(s)
      yield
    end
  ensure
    clear_server_caches
  end

  def impersonate_server(s)
    MiqServer.my_guid = s.guid
    # It is important that we continue to use the same server instance here.
    # A lot of "global" state is stored in instance variables on the server.
    @server = s
    Vmdb::Settings.init
  end

  def clear_server_caches
    MiqServer.my_guid = nil
    MiqServer.my_server_clear_cache
    Vmdb::Settings.init
  end
end
