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

  opts.on("-e=ems_id", "--ems-id=ems_id,ems_id", Array, "Provide a list of ems ids (without spaces) to a provider worker. This requires, at least one argument.") do |val|
    options[:ems_id] = val
  end

  opts.on("-h", "--help", "Displays this help") do
    puts opts
    exit
  end

  opts.on("-f", "--force", "Ignore missing server roles and run anyway") do
    options[:force] = true
  end
end
opt_parser.parse!
worker_class = ARGV[0]

require File.expand_path("../miq_worker_types", __dir__)

if options[:list]
  puts ::MIQ_WORKER_TYPES.keys
  exit
end
opt_parser.abort(opt_parser.help) unless worker_class

unless ::MIQ_WORKER_TYPES.keys.include?(worker_class)
  STDERR.puts "ERR:  `#{worker_class}` WORKER CLASS NOT FOUND!  Please run with `-l` to see possible worker class names."
  exit 1
end

# Skip heartbeating with single worker
ENV["DISABLE_MIQ_WORKER_HEARTBEAT"] ||= options[:heartbeat] ? nil : '1'
ENV["BUNDLER_GROUPS"] = MIQ_WORKER_TYPES[worker_class].join(',')

options[:ems_id] ||= ENV["EMS_ID"]

require File.expand_path("../../../config/environment", __dir__)

worker_class = worker_class.constantize
unless worker_class.has_required_role?
  STDERR.puts "ERR:  Server roles are not sufficient for `#{worker_class}` worker."
  exit 1 unless options[:force]
end

worker_class.before_fork
unless options[:dry_run]
  create_options = {:pid => Process.pid}
  runner_options = {}

  if options[:ems_id]
    create_options[:queue_name] = options[:ems_id].length == 1 ? "ems_#{options[:ems_id].first}" : options[:ems_id].collect { |id| "ems_#{id}" }
    runner_options[:ems_id]     = options[:ems_id].length == 1 ? options[:ems_id].first : options[:ems_id].collect { |id| id }
  end

  worker = if options[:guid]
             worker_class.find_by!(:guid => options[:guid]).tap do |wrkr|
               wrkr.update_attributes(:pid => Process.pid)
             end
           else
             worker_class.create_worker_record(create_options)
           end

  begin
    runner_options[:guid] = worker.guid
    worker.class::Runner.new(runner_options).tap(&:setup_sigterm_trap).start
  ensure
    worker.delete
  end
end
