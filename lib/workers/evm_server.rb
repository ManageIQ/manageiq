require 'miq-process'
require 'pid_file'

class EvmServer
  include Vmdb::Logging

  ##
  # String used as a title for a linux process. Visible in ps, htop, ...
  SERVER_PROCESS_TITLE = 'MIQ Server'.freeze

  def initialize
    $log ||= Rails.logger
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

    start_server(MiqServer.my_server(true))
  end

  ##
  # Sets the server process' name if it is possible.
  #
  def set_process_title
    Process.setproctitle(SERVER_PROCESS_TITLE) if Process.respond_to?(:setproctitle)
  end

  def self.start(*args)
    new.start
  end

  def start_server(server)
    Vmdb::Settings.activate

    save_local_network_info(server)
    set_local_server_vm(server)
    reset_server_runtime_info(server)
    log_server_info(server)

    Vmdb::Appliance.log_config_on_startup

    server.ntp_reload
    server.set_database_application_name

    EvmDatabase.seed_rest

    MiqServer.start_memcached
    MiqApache::Control.restart if MiqEnvironment::Command.supports_apache?

    MiqEvent.raise_evm_event(server, "evm_server_start")

    msg = "Server starting in #{MiqServer.startup_mode} mode."
    _log.info(msg)
    puts "** #{msg}"

    server.starting_server_record
    server.ensure_default_roles

    #############################################################
    # Server Role Assignment
    #
    # - Deactivate all roles from last time
    # - Assert database_owner role - based on vmdb being local
    # - Role activation should happen inside monitor_servers
    # - Synchronize active roles to monitor for role changes
    #############################################################
    server.deactivate_all_roles
    server.set_database_owner_role(EvmDatabase.local?)
    server.monitor_servers
    server.monitor_server_roles if server.is_master?
    server.sync_active_roles
    server.set_active_role_flags

    #############################################################
    # Clear the MiqQueue for server and its workers
    #############################################################
    server.clean_stop_worker_queue_items
    server.clear_miq_queue_for_this_server

    #############################################################
    # Other startup actions
    #############################################################
    MiqServer.log_managed_entities
    MiqServer.clean_all_workers
    MiqServer.clean_dequeued_messages
    MiqServer.purge_report_results

    server.delete_active_log_collections_queue

    #############################################################
    # Start all the configured workers
    #############################################################
    server.clean_heartbeat_files
    server.sync_config
    server.start_drb_server
    server.sync_workers
    server.wait_for_started_workers

    server.update(:status => "started")
    _log.info("Server starting complete")

    monitor_loop(server)
  end

  def monitor_loop(server)
    loop do
      _dummy, timings = Benchmark.realtime_block(:total_time) { server.monitor }
      _log.info("Server Monitoring Complete - Timings: #{timings.inspect}") unless timings[:total_time] < ::Settings.server.server_log_timings_threshold.to_i_with_method
      sleep ::Settings.server.monitor_poll.to_i_with_method
    end
  rescue Interrupt => e
    _log.info("Received #{e.message} signal, killing server")
    MiqServer.kill
    exit 1
  rescue SignalException => e
    _log.info("Received #{e.message} signal, shutting down server")
    server.shutdown_and_exit
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

  def save_local_network_info(server)
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
      Vmdb::Settings.save!(server, :server => config_hash)
      ::Settings.reload!
    end

    server.update(server_hash)
  end

  def set_local_server_vm(server)
    if server.vm_id.nil?
      vms = Vm.find_all_by_mac_address_and_hostname_and_ipaddress(server.mac_address, server.hostname, server.ipaddress)
      if vms.length > 1
        _log.warn("Found multiple Vms that may represent this MiqServer: #{vms.collect(&:id).sort.inspect}")
      elsif vms.length == 1
        server.update(:vm_id => vms.first.id)
      end
    end
  end

  def reset_server_runtime_info(server)
    server.update(
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
    _log.info("Server IP Address: #{server.ipaddress}")    unless server.ipaddress.blank?
    _log.info("Server Hostname: #{server.hostname}")       unless server.hostname.blank?
    _log.info("Server MAC Address: #{server.mac_address}") unless server.mac_address.blank?
    _log.info("Server GUID: #{MiqServer.my_guid}")
    _log.info("Server Zone: #{MiqServer.my_zone}")
    _log.info("Server Role: #{MiqServer.my_role}")
    region = MiqRegion.my_region
    _log.info("Server Region number: #{region.region}, name: #{region.name}") unless region.nil?
    _log.info("Database Latency: #{EvmDatabase.ping(ApplicationRecord.connection)} ms")
  end
end
