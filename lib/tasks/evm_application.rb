require "manageiq/active_record_connector"

require "pid_file"
require "miq_environment"
require "vmdb/logging"
require "vmdb/settings/walker"
require "more_core_extensions/core_ext/array/tableize"

class EvmApplication
  include Vmdb::Logging

  def self.start
    if server_state == :no_db
      puts "EVM has no Database connection"
      File.open(ManageIQ.root.join("tmp", "pids", "evm.pid"), "w") { |f| f.write("no_db") }
      exit
    end

    if pid = MiqServer.running?
      puts "EVM is already running (PID=#{pid})"
      exit
    end

    puts "Starting EVM..."
    _log.info("EVM Startup initiated")

    MiqServer.kill_all_workers
    command_line = "#{Gem.ruby} #{ManageIQ.root.join(*%w(lib workers bin evm_server.rb)).expand_path}"

    env_options = {}
    env_options["EVMSERVER"] = "true" if MiqEnvironment::Command.is_appliance?
    puts "Running EVM in background..."
    pid = Kernel.spawn(env_options, command_line, :pgroup => true, [:out, :err] => [ManageIQ.root.join("log/evm.log"), "a"])
    Process.detach(pid)
  end

  def self.stop
    puts "Stopping EVM gracefully..."
    _log.info("EVM Shutdown initiated")
    MiqServer.stop(true)
  end

  def self.kill
    puts "Killing EVM..."
    _log.info("EVM Kill initiated")
    MiqServer.kill
  end

  def self.server_state
    my_server.status
  rescue => error
    :no_db if error.message =~ /Connection refused/i
  end

  def self.status(include_remotes = false)
    puts "Checking EVM status..."

    server = my_server
    servers = Set.new
    servers << server if server
    if include_remotes
      servers.merge(all_other_servers(server))
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
      [s["zone"],
       s["name"],
       s["status"],
       s["id"],
       s["pid"],
       s["sql_spid"],
       s["drb_uri"],
       s["started_on"] && Time.parse(s["started_on"]).iso8601,
       s["last_heartbeat"] && Time.parse(s["last_heartbeat"]).iso8601,
       s["is_master"],
       s["active_role_names"],
      ]
    end
    header = ["Zone", "Server", "Status", "ID", "PID", "SPID", "URL", "Started On", "Last Heartbeat", "Master?", "Active Roles"]
    puts data.unshift(header).tableize
  end

  def self.output_workers_status(servers)
    data = []
    workers_for_servers(servers).each do |w|
      data <<
        [w["type"],
         w["status"],
         w["id"],
         w["pid"],
         w["sql_spid"],
         w["miq_server_id"],
         w["queue_name"] || w["uri"],
         w["started_on"] && Time.parse(w["started_on"]).iso8601,
         w["last_heartbeat"] && Time.parse(w["last_heartbeat"]).iso8601]
    end

    header = ["Worker Type", "Status", "ID", "PID", "SPID", "Server id", "Queue Name / URL", "Started On", "Last Heartbeat"]
    puts data.unshift(header).tableize unless data.empty?
  end

  def self.update_start
    require 'fileutils'
    filename = miq_server_pidfile
    tempfile = "#{filename}.yum"
    FileUtils.mkdir_p(File.dirname(filename))
    File.write(filename, "no_db") if File.file?(tempfile)
    FileUtils.rm_f(tempfile)
  end

  def self.update_stop
    return if MiqServer.my_server.status != "started"

    require 'fileutils'
    tempfile = "#{miq_server_pidfile}.yum"
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

  def self.miq_server_pidfile
    "#{ManageIQ.root}/tmp/pids/evm.pid"
  end

  def self.my_server
    query = miq_server_query.where(miq_server_table[:guid].eq(ManageIQ.my_guid))
    ActiveRecord::Base.connection.select_one(query)
  end

  def self.all_other_servers(server)
    query = miq_server_query
    query = query.where(miq_server_table[:id].not_eq(server["id"])) if server
    ActiveRecord::Base.connection.select_all(query)
  end

  def self.workers_for_servers(servers)
    server_ids = servers.collect {|s| s["id"]}
    table      = Arel::Table.new(:miq_workers, :type_caster => typecaster)
    query      = table.project(Arel.star)
                      .where(table[:miq_server_id].in(server_ids))
                      .order(table[:miq_server_id], table[:type])
    ActiveRecord::Base.connection.select_all(query)
  end

  def self.miq_server_table
    @miq_server_table ||= Arel::Table.new(:miq_servers, :type_caster => typecaster)
  end

  def self.miq_server_query
    miq_server           = miq_server_table
    zone                 = Arel::Table.new(:zones, :type_caster => typecaster)
    assigned_server_role = Arel::Table.new(:assigned_server_roles, :type_caster => typecaster)
    server_role          = Arel::Table.new(:server_roles, :type_caster => typecaster)

    miq_server_columns = [
       miq_server[:name],
       miq_server[:status],
       miq_server[:id],
       miq_server[:pid],
       miq_server[:sql_spid],
       miq_server[:drb_uri],
       miq_server[:started_on],
       miq_server[:last_heartbeat],
       miq_server[:is_master]
    ]

    miq_server.project(zone[:name].as("zone"))
              .project(*miq_server_columns)
              .project(aggregate_col server_role, :name)
              .join(zone)
                .on(miq_server[:zone_id].eq(zone[:id]))
              .join(assigned_server_role)
                .on(
                  miq_server[:id].eq(assigned_server_role[:miq_server_id])
                    .and(assigned_server_role[:active].eq(false))
                )
              .join(server_role)
                .on(assigned_server_role[:server_role_id].eq(server_role[:id]))
              .order(miq_server[:zone_id], miq_server[:status])
              .group(miq_server[:id], zone[:name])
  end

  def self.aggregate_col(table, col, delimeter="':'")
    Arel::Nodes::NamedFunction.new(
      "array_to_string",
      [
        Arel::Nodes::NamedFunction.new("array_agg", [table[col]]),
        Arel::Nodes::SqlLiteral.new(delimeter)
      ]
    )
  end

  def self.typecaster
    return @typecaster if @typecaster

    require "time"

    @typecaster = Object.new

    def @typecaster.type_cast_for_database(attr_name, val)
      case attr_name
      when /(^id$|_id$)/ then val.to_i
      when %w[started_on last_heartbeat] then Time.parse(val)
      else
        val
      end
    end

    @typecaster
  end
end
