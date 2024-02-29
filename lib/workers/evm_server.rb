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

    MiqServer.kill_all_workers

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
    @servers_to_monitor = servers_from_db if servers_to_monitor.empty?

    as_each_server { start_server }
  end

  def monitor_servers
    loop do
      refresh_servers_to_monitor
      as_each_server { monitor }
      sleep ::Settings.server.monitor_poll.to_i_with_method
    end
  end

  def stop_servers
    as_each_server { @current_server.shutdown }
  end

  def kill_servers
    as_each_server do
      @current_server.worker_manager.kill_all_workers
      @current_server.update(:stopped_on => Time.now.utc, :status => "killed", :is_master => false)
    end
  end

  def refresh_servers_to_monitor
    servers_to_start    = servers_from_db    - servers_to_monitor
    servers_to_shutdown = servers_to_monitor - servers_from_db

    servers_to_start.each do |s|
      servers_to_monitor << s
      impersonate_server(s)
      start_server
    end

    servers_to_shutdown.each do |s|
      servers_to_monitor.delete(s)
      s.shutdown
    end
  end

  def self.start(*_args)
    new.start
  end

  private

  def servers_from_db
    my_server = MiqServer.my_server(true)

    if MiqEnvironment::Command.is_podified?
      # Ensure that the "primary" miq_server is first in the list of servers.
      # This ensures that any work that is only done on the primary is completed
      # before processing the rest of the servers.
      MiqServer.in_my_region.to_a.unshift(my_server).uniq.compact
    else
      [my_server].compact
    end
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

    @current_server.set_database_application_name

    EvmDatabase.seed_rest

    MiqEvent.raise_evm_event(@current_server, "evm_server_start")

    _log.info("Server starting...")
    puts "** Server starting..."

    @current_server.starting_server_record

    configure_server_roles
    clear_queue

    MiqServer.startup!

    @current_server.delete_active_log_collections_queue

    start_workers

    @current_server.update(:status => "started")
    _log.info("Server starting...Complete")
    puts "** Server starting...Complete"
  end

  def monitor
    _dummy, timings = Benchmark.realtime_block(:total_time) { @current_server.monitor }
    _log.info("Server Monitoring Complete - Timings: #{timings.inspect}") unless timings[:total_time] < ::Settings.server.server_log_timings_threshold.to_i_with_method
  end

  def validate_database
    # Remove the connection and establish a new one since reconnect! doesn't always play nice with SSL postgresql connections
    spec_name = ActiveRecord::Base.connection_specification_name
    ActiveRecord::Base.establish_connection(ActiveRecord::Base.remove_connection(spec_name))

    # Log the Versions
    _log.info("Database Adapter: [#{ActiveRecord::Base.connection.adapter_name}], version: [#{ActiveRecord::Base.connection.database_version_details}]") if ActiveRecord::Base.connection.respond_to?(:database_version_details)
  end

  def check_migrations_up_to_date
    up_to_date, *message = SchemaMigration.up_to_date?
    level = up_to_date ? :info : :warn
    Array.wrap(message.presence).each { |msg| _log.send(level, msg) }
    up_to_date
  end

  def save_local_network_info
    server_hash = {}
    config_hash = {}

    ipaddr, hostname, mac_address = MiqServer.get_network_information

    if ipaddr&.match?(Regexp.union(Resolv::IPv4::Regex, Resolv::IPv6::Regex).freeze)
      server_hash[:ipaddress] = config_hash[:host] = ipaddr
    end

    if hostname.present? && hostname.hostname?
      hostname = nil if /.*localhost.*/.match?(hostname)
      server_hash[:hostname] = config_hash[:hostname] = hostname
    end

    if mac_address.present?
      server_hash[:mac_address] = mac_address
    end

    if config_hash.any?
      Vmdb::Settings.save!(@current_server, :server => config_hash)
      ::Settings.reload!
    end

    @current_server.update(server_hash)
  end

  def set_local_server_vm
    if @current_server.vm_id.nil?
      vms = Vm.find_all_by_mac_address_and_hostname_and_ipaddress(@current_server.mac_address, @current_server.hostname, @current_server.ipaddress)
      if vms.length > 1
        _log.warn("Found multiple Vms that may represent this MiqServer: #{vms.collect(&:id).sort.inspect}")
      elsif vms.length == 1
        @current_server.update(:vm_id => vms.first.id)
      end
    end
  end

  def reset_server_runtime_info
    @current_server.update(
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
    _log.info("Server IP Address: #{@current_server.ipaddress}")    if @current_server.ipaddress.present?
    _log.info("Server Hostname: #{@current_server.hostname}")       if @current_server.hostname.present?
    _log.info("Server MAC Address: #{@current_server.mac_address}") if @current_server.mac_address.present?
    _log.info("Server GUID: #{MiqServer.my_guid}")
    _log.info("Server Zone: #{MiqServer.my_zone}")
    _log.info("Server Role: #{MiqServer.my_role}")
    region = MiqRegion.my_region
    _log.info("Server Region number: #{region.region}, name: #{region.name}") unless region.nil?
    _log.info("Database Latency: #{EvmDatabase.ping(ApplicationRecord.connection)} ms")
  end

  def configure_server_roles
    @current_server.ensure_default_roles

    #############################################################
    # Server Role Assignment
    #
    # - Deactivate all roles from last time
    # - Assert database_owner role - based on vmdb being local
    # - Role activation should happen inside monitor_servers
    # - Synchronize active roles to monitor for role changes
    #############################################################
    @current_server.deactivate_all_roles
    @current_server.set_database_owner_role(EvmDatabase.local?)
    @current_server.server_monitor.monitor_servers
    @current_server.monitor_server_roles if @current_server.is_master?
    @current_server.sync_active_roles
    @current_server.set_active_role_flags
  end

  def clear_queue
    #############################################################
    # Clear the MiqQueue for server and its workers
    #############################################################
    @current_server.clean_stop_worker_queue_items
    @current_server.clear_miq_queue_for_this_server
  end

  def start_workers
    #############################################################
    # Start all the configured workers
    #############################################################
    @current_server.start_workers
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
  def as_each_server
    initial_server = @current_server
    servers_to_monitor.each do |s|
      impersonate_server(s)
      yield
    end
  ensure
    clear_server_caches if @current_server != initial_server
  end

  def impersonate_server(s)
    return if s == @current_server

    _log.info("Impersonating server - id: #{s.id}, guid: #{s.guid}")

    MiqServer.my_server_clear_cache
    MiqServer.my_guid = s.guid

    # It is important that we continue to use the same server instance here.
    # A lot of "global" state is stored in instance variables on the server.
    @current_server = s
    Vmdb::Settings.reset_settings_constant(s.settings_for_resource)
  end

  def clear_server_caches
    MiqServer.my_guid = nil
    MiqServer.my_server_clear_cache
    # Use Vmdb::Settings.for_resource(:my_server) here as MiqServer.my_server might be nil
    Vmdb::Settings.reset_settings_constant(Vmdb::Settings.for_resource(:my_server))
  end
end
