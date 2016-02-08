RAILS_ROOT = ENV["RAILS_ENV"] ? Rails.root : File.expand_path(File.join(__dir__, %w(.. ..)))
$:.push File.join(RAILS_ROOT, "gems/pending/util") unless ENV["RAILS_ENV"]

require 'miq_logger_processor'
require 'time'

$targets      = nil
$target_types = nil
$logfiles     = []

def usage
  %{usage: ruby ems_refresh_timings.rb [OPTION]... [FILE]...
Description:
  Parse EMS Refreshes from a set of evm.log files and filter on a set of
  provided conditions.
Options:
  --target-type=TYPES  Comma separated list of target types to filter, if not
                       specified all target types will be shown
  --target=TARGETS     Comma separated list of targets to filter, if not
                       specified all targets will be shown.
  --time=FROM,TO       Range of dates to include (will be the start date).
  -h, --help           Print this message and exit.
Files:
  Set of paths to evm.log files, if not specified the log/evm.log file in
  RAILS_ROOT will be used.  If multiple files are provided all of their
  refreshes will be combined and sorted by time.
Examples:
  Print all full provider refreshes in main log/evm.log file:
    ruby tools/log_processing/ems_refresh_timings.rb --target-type=EmsVmware
  Print all refreshes between two dates:
    ruby tools/log_processing/ems_refresh_timings.rb --date=2016-01-23,2016-01-24
  Print all full provider refreshes for a set of logs:
    find /path/to/logs -name 'evm.log*' | \\
    xargs ruby tools/log_processing/ems_refresh_timings.rb --target-type=EmsVmware
}
end

def parse_args(argv)
  ARGV.each_with_index do |arg, i|
    if arg.start_with?('-')
      flag, optarg = arg.split('=')
      case flag
      when '--target'
        $targets = optarg.split(',')
      when '--target-type'
        $target_types = optarg.split(',')
      when '--time'
        # TODO: unimplemented
      when '--help', '-h'
        print usage()
        exit
      else
        print "unknown argument #{arg}\n"
        abort(usage())
      end
    elsif File.file?(arg)
      $logfiles << File.expand_path(arg)
    end
  end

  $logfiles << File.join(RAILS_ROOT, "log/evm.log") if $logfiles.empty?
end

def filter(hash)
  return false unless $target_types.nil? || $target_types.include?(hash[:target_type])
  return false unless $targets.nil? || $targets.include?(hash[:target])
  return true
end

parse_args(ARGV)

puts "Processing file..."

all_timings = []
ems_timings = Hash.new { |k, v| k[v] = [] }
all_targets = Hash.new { |k, v| k[v] = [] }

$logfiles.each do |logfile|
  MiqLoggerProcessor.new(logfile).each do |line|
    # Find the target type
    if line =~ /MIQ\(VcRefresher.refresh\).EMS:? \[(.*?)\].+Refreshing target ([^\s]+).\[(.*?)\].+Complete/
      ems         = $1
      target_type = $2
      target      = $3

      all_targets[ems] << {
        :time        => line.time,
        :target      => target,
        :target_type => target_type
      }
    end

    next unless line =~ /MIQ\(VcRefresher.refresh\).EMS:? \[(.*?)\].+Timings:? (\{.+)$/
    ems     = $1
    timings = eval($2)

    timings[:end_time]    = Time.parse(line.time + " UTC")
    timings[:start_time]  = timings[:end_time] - timings[:total_time]
    timings[:target_type] = all_targets[ems].last[:target_type]
    timings[:target]      = all_targets[ems].last[:target]
    timings[:ems]         = ems

    if filter(timings)
      all_timings      << timings
      ems_timings[ems] << timings
    end
  end
end

print "Found #{all_timings.length} refreshes from #{ems_timings.keys.length} providers\n"

COLUMNS           = ["start", "end", "duration", "ems", "target-type", "target"]
COLUMN_MAX_LENGTH = [ 0, 0, 0, 0, 0, 0]
all_timings.sort_by { |t| t[:start_time] }.each do |timing|
  COLUMN_MAX_LENGTH[0] = [COLUMN_MAX_LENGTH[0], timing[:start_time].to_s.length].max
  COLUMN_MAX_LENGTH[1] = [COLUMN_MAX_LENGTH[1], timing[:end_time].to_s.length].max
  COLUMN_MAX_LENGTH[2] = [COLUMN_MAX_LENGTH[2], timing[:total_time].to_s.length].max
  COLUMN_MAX_LENGTH[3] = [COLUMN_MAX_LENGTH[3], timing[:ems].length].max
  COLUMN_MAX_LENGTH[4] = [COLUMN_MAX_LENGTH[4], timing[:target_type].length].max
  COLUMN_MAX_LENGTH[5] = [COLUMN_MAX_LENGTH[5], timing[:target].length].max
end

COLUMNS.each_with_index do |col, i|
  print "#{col.ljust(COLUMN_MAX_LENGTH[i])}   "
end
print "\n"

all_timings.sort_by { |t| t[:start_time] }.each do |timing|
  print "#{timing[:start_time].to_s.ljust(COLUMN_MAX_LENGTH[0])} | #{timing[:end_time].to_s.ljust(COLUMN_MAX_LENGTH[1])} | #{timing[:total_time].to_s.ljust(COLUMN_MAX_LENGTH[2])} | #{timing[:ems].to_s.ljust(COLUMN_MAX_LENGTH[3])} | #{timing[:target_type].to_s.ljust(COLUMN_MAX_LENGTH[4])} | #{timing[:target].to_s.ljust(COLUMN_MAX_LENGTH[5])}\n"
end
