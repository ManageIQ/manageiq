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
  return false unless $targets.nil?      || $targets.include?(hash[:target])
  return true
end

def parse_refresh_target(line)
  if line =~ /MIQ\(VcRefresher.refresh\).EMS:? \[(.*?)\].+Refreshing target ([^\s]+).\[(.*?)\].+Complete/
    {
      :time        => line.time,
      :ems         => $1,
      :target_type => $2,
      :target      => $3
    }
  end
end

def parse_refresh_timings(line)
  if line =~ /MIQ\(VcRefresher.refresh\).EMS:? \[(.*?)\].+Timings:? (\{.+)$/
    ems             = $1
    refresh_timings = eval($2)

    refresh_timings[:ems]         = ems
    refresh_timings[:end_time]    = Time.parse(line.time + " UTC")
    refresh_timings[:start_time]  = refresh_timings[:end_time] - refresh_timings[:total_time]

    refresh_timings
  end
end

def sort_timings(timings)
  timings.sort_by { |t| t[:start_time] }
end

def print_results(all_timings, ems_timings)
  columns        = [:start_time, :end_time, :total_time, :ems, :target_type, :target]
  column_lengths = [ 0, 0, 0, 0, 0, 0]

  print "Found #{all_timings.length} refreshes from #{ems_timings.keys.length} providers\n"

  # Calculate how much padding we need for each column
  sort_timings(all_timings).each do |timing|
    (0..columns.length - 1).each do |i|
      column_lengths[i] = [column_lengths[i], timing[columns[i]].to_s.length].max
    end
  end

  # Print the column headers
  columns.each_with_index do |col, i|
    print "#{col.to_s.ljust(column_lengths[i])}   "
  end

  print "\n"

  # Print the results for each refresh
  sort_timings(all_timings).each do |timing|
    column_lengths.each_with_index do |column_length, i|
      print "#{timing[columns[i]].to_s.ljust(column_length)} | "
    end
    print "\n"
  end
end


parse_args(ARGV)

puts "Processing file..."

all_timings = []
ems_timings = Hash.new { |k, v| k[v] = [] }
all_targets = Hash.new { |k, v| k[v] = [] }

$logfiles.each do |logfile|
  MiqLoggerProcessor.new(logfile).each do |line|
    # Find the target type
    if target_hash = parse_refresh_target(line)
      all_targets[target_hash[:ems]] << target_hash
    end

    if refresh_timings = parse_refresh_timings(line)
      ems = refresh_timings[:ems]

      refresh_timings[:target]      = all_targets[ems].last[:target]
      refresh_timings[:target_type] = all_targets[ems].last[:target_type]

      if filter(refresh_timings)
        ems_timings[refresh_timings[:ems]] << refresh_timings
        all_timings                        << refresh_timings
      end
    end
  end
end

print_results(all_timings, ems_timings)
