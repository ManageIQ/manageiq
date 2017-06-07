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

  opts.on("-h", "--help", "Displays this help") do
    puts opts
    exit
  end
end

opt_parser.parse!
if options[:list]
  # Hack to make this faster
  module MiqServer; module WorkerManagement; module Monitor;
  end; end; end;

  require 'active_support/concern'
  require File.expand_path("../../../app/models/miq_server/worker_management/monitor/class_names", __dir__)

  puts MiqServer::WorkerManagement::Monitor::ClassNames::MONITOR_CLASS_NAMES
  exit
end
opt_parser.abort(opt_parser.help) if ARGV.empty?

# Skip heartbeating with single worker
ENV["DISABLE_MIQ_WORKER_HEARTBEAT"] ||= '1'

require File.expand_path("../../../config/environment", __dir__)

worker_list  = MiqServer::WorkerManagement::Monitor::ClassNames::MONITOR_CLASS_NAMES
worker_class = ARGV[0]

unless worker_list.include?(worker_class)
  puts "ERR:  `#{worker_class}` WORKER CLASS NOT FOUND!  Please run with `-l` to see possible worker class names."
  exit 1
end

worker_class = worker_class.constantize
worker = worker_class.create_worker_record
worker_class.before_fork
begin
  worker.class::Runner.start_worker(:guid => worker.guid)
ensure
  worker.delete
end
