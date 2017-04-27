require File.expand_path("../../tools/utils/mini_miq_server", __dir__)
require "vmdb/logging"
require "more_core_extensions/core_ext/array/tableize"

class EvmApplication
  include Vmdb::Logging

  VMDB_ROOT = File.expand_path("../..", File.dirname(__FILE__)).freeze

  def self.start
    if server_state == :no_db
      puts "EVM has no Database connection"
      File.open(File.join(VMDB_ROOT, "tmp", "pids", "evm.pid"), "w") { |f| f.write("no_db") }
      exit
    end

    if pid = Mini::MiqServer.running?
      puts "EVM is already running (PID=#{pid})"
      exit
    end

    puts "Starting EVM..."
    _log.info("EVM Startup initiated")

    include_miq_killer
    Mini::MiqServer.kill_all_workers
    evm_server_file = File.join(*([VMDB_ROOT] + %w(lib workers bin evm_server.rb)))
    command_line = "#{Gem.ruby} #{evm_server_file}"
    puts command_line

    env_options = {}
    env_options["EVMSERVER"] = "true" if MiqEnvironment::Command.is_appliance?
    puts "Running EVM in background..."
    pid = Kernel.spawn(env_options, command_line, :pgroup => true, [:out, :err] => [File.join(VMDB_ROOT, "log/evm.log"), "a"])
    Process.detach(pid)
  end

  def self.stop
    puts "Stopping EVM gracefully..."
    _log.info("EVM Shutdown initiated")
    Mini::MiqServer.stop(true)
  end

  def self.kill
    puts "Killing EVM..."
    _log.info("EVM Kill initiated")
    Mini::MiqServer.kill
  end

  def self.server_state
    Mini::MiqServer.my_server.status
  rescue => error
    :no_db if error.message =~ /Connection refused/i
  end

  def self.status(include_remotes = false)
    puts "Checking EVM status..."

    server = Mini::MiqServer.my_server
    servers = Set.new
    servers << server if server
    if include_remotes
      all_servers =
        Mini::MiqServer
        .order(:zone_id, :status)
        .includes(:active_roles, :miq_workers, :zone)
        .all.to_a
      servers.merge(all_servers)
    end

    if servers.empty?
      puts "Local EVM Server not Found"
    else
      output_servers_status(servers)
      puts "\n"
      output_workers_status(servers)
    end
  end

  def self.output_servers_status(servers)
    data = servers.collect do |s|
      [s.zone.name,
       s.name,
       s.status,
       s.id,
       s.pid,
       s.sql_spid,
       s.drb_uri,
       s.started_on && s.started_on.iso8601,
       s.last_heartbeat && s.last_heartbeat.iso8601,
       s.is_master,
       s.active_role_names.join(':'),
      ]
    end
    header = ["Zone", "Server", "Status", "ID", "PID", "SPID", "URL", "Started On", "Last Heartbeat", "Master?", "Active Roles"]
    puts data.unshift(header).tableize
  end

  def self.output_workers_status(servers)
    data = []
    servers.each do |s|
      s.miq_workers.order(:type).each do |w|
        data <<
          [w.type,
           w.status,
           w.id,
           w.pid,
           w.sql_spid,
           w.miq_server_id,
           w.queue_name || w.uri,
           w.started_on && w.started_on.iso8601,
           w.last_heartbeat && w.last_heartbeat.iso8601]
      end
    end

    header = ["Worker Type", "Status", "ID", "PID", "SPID", "Server id", "Queue Name / URL", "Started On", "Last Heartbeat"]
    puts data.unshift(header).tableize unless data.empty?
  end

  def self.update_start
    require 'fileutils'
    filename = Mini::MiqServer.pidfile
    tempfile = "#{filename}.yum"
    FileUtils.mkdir_p(File.dirname(filename))
    File.write(filename, "no_db") if File.file?(tempfile)
    FileUtils.rm_f(tempfile)
  end

  def self.update_stop
    return if Mini::MiqServer.my_server.status != "started"

    require 'fileutils'
    tempfile = "#{Mini::MiqServer.pidfile}.yum"
    FileUtils.mkdir_p(File.dirname(tempfile))
    File.write(tempfile, " ")
    stop
  end

  def self.set_region_file(region_file, new_region)
    old_region = region_file.exist? ? region_file.read.to_i : nil

    return if new_region == old_region

    _log.info("Changing REGION file from [#{old_region}] to [#{new_region}]. Restart to use the new region.")
    region_file.write(new_region)
  end

  def self.include_miq_killer
    require File.expand_path("../../app/models/miq_server/worker_management/monitor/kill.rb", __dir__)

    Mini::MiqServer.send(:include, MiqServer::WorkerManagement::Monitor::Kill)
  end
end
