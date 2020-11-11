require 'pid_file'

class EvmApplication
  include Vmdb::Logging

  def self.start
    if server_state == :no_db
      puts "EVM has no Database connection"
      File.open(Rails.root.join("tmp", "pids", "evm.pid"), "w") { |f| f.write("no_db") }
      exit
    end

    if pid = MiqServer.running?
      puts "EVM is already running (PID=#{pid})"
      exit
    end

    puts "Starting EVM..."
    _log.info("EVM Startup initiated")

    MiqServer.kill_all_workers
    command_line = "#{Gem.ruby} #{Rails.root.join(*%w(lib workers bin evm_server.rb)).expand_path}"

    env_options = {}
    env_options["EVMSERVER"] = "true" if MiqEnvironment::Command.is_appliance?
    puts "Running EVM in background..."
    pid = Kernel.spawn(env_options, command_line, :pgroup => true, [:out, :err] => [Rails.root.join("log/evm.log"), "a"])
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
    MiqServer.my_server.status
  rescue => error
    :no_db if error.message =~ /Connection refused/i
  end

  def self.status(include_remotes = false)
    puts "Checking EVM status..."

    server = MiqServer.my_server(true)
    servers =
      if include_remotes
        MiqServer.includes(:active_roles, :miq_workers, :zone).all.to_a
      else
        [server]
      end

    if servers.empty?
      puts "Local EVM Server not Found"
    else
      output_status(servers_status(servers), "* marks a master appliance")
      puts "\n"
      output_status(workers_status(servers))
    end
  end

  def self.output_status(data, footnote = nil)
    return if data.blank?
    duplicate_columns = redundant_columns(data)
    duplicate_columns.delete("Status") # always show status
    puts data.tableize(:columns => (data.first.keys - duplicate_columns.keys))

    # dont give headsup for empty values
    heads_up = duplicate_columns.select { |n, v| n == "Region" || (v != 0 && v.present?) }
    if heads_up.present?
      puts "", "All rows have the values: #{heads_up.map { |n, v| "#{n}=#{v}" }.join(", ")}"
      puts footnote if footnote
    elsif footnote
      puts "", footnote
    end
  end

  def self.redundant_columns(data, column_names = nil, dups = {})
    return dups if data.size <= 1
    column_names ||= data.first.keys
    column_names.each do |col_header|
      values = data.collect { |row| row[col_header] }.uniq
      dups[col_header] = values.first if values.size < 2
    end
    dups
  end
  private_class_method :redundant_columns

  def self.compact_date(date)
    return "" unless date
    date < 1.day.ago ? date.strftime("%Y-%m-%d") : date.strftime("%H:%M:%S%Z")
  end
  private_class_method :compact_date

  def self.compact_queue_uri(queue_name, uri)
    if queue_name.nil?
      if uri
        uri_parts = uri.split(":")
        [uri_parts.first, uri_parts.last].join(":")
      else
        ""
      end
    elsif queue_name.kind_of?(Array)
      queue_name.join(":")
    else
      queue_name
    end
  end

  def self.servers_status(servers)
    data = servers.collect do |s|
      {
        "Region"       => s.region_number,
        "Zone"      => s.zone.name,
        "Server"    => (s.name || "UNKNOWN") + (s.is_master ? "*" : ""),
        "Status"    => s.status,
        "PID"       => s.pid,
        "SPID"      => s.sql_spid,
        "Workers"   => s.miq_workers.size,
        "Version"   => s.version,
        "Started"   => compact_date(s.started_on),
        "Heartbeat" => compact_date(s.last_heartbeat),
        "MB Usage"  => (mem = (s.unique_set_size || s.memory_usage)).nil? ? "" : mem / 1.megabyte,
        "Roles"     => s.active_role_names.join(':'),
      }
    end
    data.sort_by { |s| [s["Region"], s["Zone"], s["Server"]] }
  end

  def self.workers_status(servers)
    data = servers.flat_map do |s|
      s.miq_workers.collect do |w|
        mb_usage = w.proportional_set_size || w.memory_usage
        mb_threshold = w.worker_settings[:memory_threshold]
        simple_type = w.type&.gsub(/(ManageIQ::Providers::|Manager|Worker|Miq)/, '')
        {
          "Region"       => s.region_number,
          "Zone"      => s.zone.name,
          "Type"      => simple_type,
          "Status"    => w.status.sub("stopping", "stop pending"),
          "PID"       => w.pid,
          "SPID"      => w.sql_spid,
          "Server"    => s.name,
          "Queue"     => compact_queue_uri(w.queue_name, w.uri),
          "Started"   => compact_date(w.started_on),
          "Heartbeat" => compact_date(w.last_heartbeat),
          "System UID" => w.system_uid,
          "MB Usage"  => mb_usage ? "#{mb_usage / 1.megabyte}/#{mb_threshold / 1.megabyte}" : ""
        }
      end
    end
    data.sort_by { |w| [w["Region"], w["Zone"], w["Server"], w["Type"], w["PID"]] }
  end

  def self.update_start
    require 'fileutils'
    filename = MiqServer.pidfile
    tempfile = "#{filename}.yum"
    FileUtils.mkdir_p(File.dirname(filename))
    File.write(filename, "no_db") if File.file?(tempfile)
    FileUtils.rm_f(tempfile)
  end

  def self.update_stop
    return if MiqServer.my_server.status != "started"

    require 'fileutils'
    tempfile = "#{MiqServer.pidfile}.yum"
    FileUtils.mkdir_p(File.dirname(tempfile))
    File.write(tempfile, " ")
    stop
  end

  def self.set_region_file(region_file, new_region)
    old_region = region_file.read.to_i if region_file.exist?

    return if new_region == old_region

    _log.info("Changing REGION file from [#{old_region}] to [#{new_region}]. Restart to use the new region.")
    region_file.write(new_region)
  end

  def self.encryption_key_valid?
    # if we're a new deployment we won't even be able to get the database row
    # and if there is no database row, allow this key to be used
    return true if deployment_status == "new_deployment"
    return true unless (db = MiqDatabase.first)

    # both of these should raise if we have the wrong key
    db.session_secret_token
    db.csrf_secret_token

    true
  rescue ManageIQ::Password::PasswordError
    false
  end

  def self.deployment_status
    context = ActiveRecord::MigrationContext.new(Rails.application.config.paths["db/migrate"])
    return "new_deployment" if context.current_version.zero?
    return "new_replica"    if MiqServer.my_server.nil?
    return "upgrade"        if context.needs_migration?
    "redeployment"
  end

  def self.queue_overview
    output_status(queue_status)
  end

  def self.queue_status
    MiqQueue.select(:zone, :queue_name, :role, :class_name, :method_name)
            .select('min(coalesce(deliver_on, created_on)) as oldest')
            .select('count(*) as count')
            .group(:zone, :queue_name, :role, :class_name, :method_name)
            .order(:zone, :queue_name, :role, 'oldest desc', :class_name, :method_name)
            .map do |e|
              {
                "Zone"   => e.zone,
                "Queue"  => e.queue_name,
                "Role"   => e.role,
                "method" => "#{e.class_name}.#{e.method_name}",
                "oldest" => e['oldest'].strftime("%Y-%m-%d"),
                "count"  => e['count']
              }
            end
  end
end
