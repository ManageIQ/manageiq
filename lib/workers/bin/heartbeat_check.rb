require "optparse"

options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = "usage: #{File.basename($PROGRAM_NAME, '.rb')} [HEARTBEAT_FILE]"

  opts.on("-b=HBFILE", "--heartbeat-file=HBFILE", "Heartbeat file to read (overrides arg val)") do |val|
    options[:heartbeat_file] = val
  end

  opts.on("-g=GUID", "--guid=GUID", "Use this guid for finding the heartbeat file") do |val|
    options[:guid] = val
  end

  opts.on("-v", "--[no-]verbose", "Verbose output") do |val|
    options[:verbose] = val
  end

  opts.on("-h", "--help", "Displays this help") do
    puts opts
    exit
  end
end
opt_parser.parse!

require "English"
require File.expand_path("../../heartbeat.rb", __FILE__)
heartbeat_file   = options[:heartbeat_file] || ARGV[0]
heartbeat_file ||= Workers::MiqDefaults.heartbeat_file(options[:guid])

exit_status = Workers::Heartbeat.file_check(heartbeat_file)

at_exit { puts $ERROR_INFO.status if options[:verbose] }
exit exit_status
