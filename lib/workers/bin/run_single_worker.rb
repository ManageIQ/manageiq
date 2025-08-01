#!/usr/bin/env ruby

# Runs a single MiqWorker class in isolation
#
#
# The following rubocop rules don't apply to this script
#
# rubocop:disable Rails/Output, Rails/Exit

require "optparse"

options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = "usage: #{File.basename($PROGRAM_NAME, '.rb')} MIQ_WORKER_CLASS_NAME"

  opts.on("-l", "--[no-]list", "Toggle viewing available worker class names") do |val|
    options[:list] = val
  end

  opts.on("-b", "--[no-]heartbeat", "Toggle heartbeating with worker monitor (DRB)") do |val|
    options[:heartbeat] = val
  end

  opts.on("-d", "--[no-]dry-run", "Dry run (don't create/start worker)") do |val|
    options[:dry_run] = val
  end

  opts.on("-g=GUID", "--guid=GUID", "Find an existing worker record instead of creating") do |val|
    options[:guid] = val
  end

  opts.on("-e=ems_id", "--ems-id=ems_id", "Provide a list of ems ids (without spaces) to a provider worker. This requires, at least one argument.") do |val|
    options[:ems_id] = val
  end

  opts.on("-s=system_uid", "--system-uid=system_uid", "Set the system uid correlating a MiqWorker row to an external system's resource.") do |val|
    options[:system_uid] = val
  end

  opts.on("-h", "--help", "Displays this help") do
    puts opts
    exit
  end

  opts.on("-r=ROLE", "--roles=role1,role2",
          "Set a list of active roles for the worker (comma separated, no spaces) or --roles=? to list all roles") do |val|
    if val == "?"
      puts all_role_names
      exit
    end
    options[:roles] = val.split(",")
  end
end

def all_role_names
  path = File.expand_path("../../../db/fixtures/server_roles.csv", __dir__)
  roles = File.read(path).lines.collect do |line|
    line.split(",").first
  end
  roles.shift
  roles
end

opt_parser.parse!
worker_class = ARGV[0]

puts "** Booting #{worker_class} with PID: #{Process.pid}#{" and options: #{options.inspect}" if options.any?}..." unless options[:list]
require File.expand_path("../../../config/environment", __dir__)

if options[:list]
  puts MiqWorkerType.pluck(:worker_type)
  exit
end
opt_parser.abort(opt_parser.help) unless worker_class

unless MiqWorkerType.find_by(:worker_type => worker_class)
  STDERR.puts "ERR:  `#{worker_class}` WORKER CLASS NOT FOUND!  Please run with `-l` to see possible worker class names."
  exit 1
end

# Skip heartbeating with single worker
ENV["DISABLE_MIQ_WORKER_HEARTBEAT"] ||= options[:heartbeat] ? nil : '1'

options[:ems_id] ||= ENV.fetch("EMS_ID", nil)

if options[:roles].present?
  MiqServer.my_server.server_role_names += options[:roles]
  MiqServer.my_server.activate_roles(MiqServer.my_server.server_role_names)
end

worker_class = worker_class.constantize
unless worker_class.has_required_role?
  STDERR.puts "ERR:  Server roles are not sufficient for `#{worker_class}` worker."
  exit 1
end

worker_class.preload_for_worker_role if worker_class.respond_to?(:preload_for_worker_role)
unless options[:dry_run]
  worker_options = {:pid => Process.pid}
  runner_options = {}

  worker_options[:system_uid] = options[:system_uid] if options[:system_uid]

  if options[:ems_id]
    worker_options[:queue_name] = "ems_#{options[:ems_id]}"
    runner_options[:ems_id]     = options[:ems_id]
  end

  find_options = options.slice(:guid, :system_uid)

  # If a guid or system_uid is provided, update if found, create if not found.
  #
  # Podified needs to create on the first run_single_worker and update after since
  # the GUID can't be predetermined for each replica
  worker = worker_class.find_by(find_options) if find_options.present?
  worker&.update(worker_options)
  worker ||= worker_class.create_worker_record(worker_options)

  begin
    runner_options[:guid] = worker.guid
    $log.info("Starting #{worker.class.name} with runner options #{runner_options}")
    worker.class::Runner.new(runner_options).tap(&:setup_sigterm_trap).start
  rescue SystemExit
    raise
  rescue Exception => err
    MiqWorker::Runner.safe_log(worker, "An unhandled error has occurred: #{err}\n#{err.backtrace.join("\n")}", :error)
    STDERR.puts("ERROR: An unhandled error has occurred: #{err}. See log for details.") rescue nil
    exit 1
  ensure
    FileUtils.rm_f(worker.heartbeat_file)
    $log.info("Deleting worker record for #{worker.class.name}, id #{worker.id}")
    worker.delete
  end
end
