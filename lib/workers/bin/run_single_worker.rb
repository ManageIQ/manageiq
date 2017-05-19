# Runs a single MiqWorker class in isolation
#
#
# The following rubocop rules don't apply to this script
#
# rubocop:disable Rails/Output, Rails/Exit

require "optparse"

options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = "usage: #{File.basename $PROGRAM_NAME, '.rb'} MIQ_WORKER_CLASS_NAME"

  opts.on("-l", "--[no-]list", "Toggle viewing available worker class names") do |val|
    options[:list] = val
  end

  opts.on("-b", "--[no-]heartbeat", "Toggle heartbeating with worker monitor (DRB)") do |val|
    options[:heartbeat] = val
  end

  opts.on("-h", "--help", "Displays this help") do
    puts opts
    exit
  end
end
opt_parser.parse!
worker_class = ARGV[0]

require File.expand_path("../miq_worker_types", __dir__)

if options[:list]
  puts ::MIQ_WORKER_TYPES
  exit
end
opt_parser.abort(opt_parser.help) unless worker_class

unless ::MIQ_WORKER_TYPES.include?(worker_class)
  puts "ERR:  `#{worker_class}` WORKER CLASS NOT FOUND!  Please run with `-l` to see possible worker class names."
  exit 1
end

# Skip heartbeating with single worker
ENV["DISABLE_MIQ_WORKER_HEARTBEAT"] ||= options[:heartbeat] ? nil : '1'

require File.expand_path("../../../config/environment", __dir__)

worker_class = worker_class.constantize
worker = worker_class.create_worker_record
worker_class.before_fork
begin
  worker.class::Runner.start_worker(:guid => worker.guid)
ensure
  worker.delete
end
