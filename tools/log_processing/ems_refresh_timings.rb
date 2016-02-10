RAILS_ROOT = ENV['RAILS_ENV'] ? Rails.root : File.expand_path(File.join(__dir__, %w(.. ..)))
$LOAD_PATH.push File.join(RAILS_ROOT, 'gems/pending/util') unless ENV['RAILS_ENV']

require 'miq_logger_processor'
require 'trollop'
require 'time'

def parse_args(argv)
  logfiles = []

  opts = Trollop.options do
    banner <<-EOS
Parse EMS Refreshes from a set of evm.log files and filter on a set of
provided conditions.

Usage:
  ruby ems_refresh_timings.rb [OPTION]... <FILE>...

Options:
EOS
    opt :sort_by, 'Column to sort by, options are start_time, end_time, '\
                  'total_time, ems, target_type, and target',
        :type => :string, :default => 'start_time'
    opt :target, 'Filter by specific targets, comma separated', :type => :strings
    opt :target_type, 'Filter by specific target types, comma separated', :type => :strings
    opt :ems, 'Filter by a specific ems, comma separted', :type => :strings
  end

  argv.each do |arg|
    logfiles << File.expand_path(arg) if File.file?(arg)
  end

  # If no logs were given on command line default to main project evm.log
  logfiles << File.join(RAILS_ROOT, 'log/evm.log') if logfiles.empty?

  [opts, logfiles]
end

def filter(hash, opts = {})
  return false unless opts[:target_type].nil? || opts[:target_type].include?(hash[:target_type])
  return false unless opts[:target].nil? || opts[:target].include?(hash[:target])
  return false unless opts[:ems].nil? || opts[:ems].include?(hash[:ems])
  true
end

def parse_refresh_target(line)
  if line =~ /EMS:? \[(.*?)\].+Refreshing target ([^\s]+).\[(.*?)\].+Complete/
    {
      :time        => line.time,
      :ems         => Regexp.last_match[1],
      :target_type => Regexp.last_match[2],
      :target      => Regexp.last_match[3]
    }
  end
end

def parse_refresh_timings(line, targets)
  if line =~ /EMS:? \[(.*?)\].+Refreshing targets for EMS...Complete - Timings:? (\{.+)$/
    ems             = Regexp.last_match[1]
    # Refresh timings are printed to the log as a hash, just eval it
    refresh_timings = eval(Regexp.last_match[2])

    # Find the most recent refresh target for our ems, since there is
    # only one refresh worker this "has to be" the right one
    # If this changes in the future we'll have to add a PID lookup here
    refresh_target  = targets[ems].last

    # Add other useful information to the refresh timings
    refresh_timings[:ems]         = ems
    refresh_timings[:end_time]    = Time.parse(line.time + ' UTC')
    refresh_timings[:start_time]  = refresh_timings[:end_time] - refresh_timings[:total_time]
    refresh_timings[:target]      = refresh_target[:target]
    refresh_timings[:target_type] = refresh_target[:target_type]

    refresh_timings
  end
end

def sort_timings(timings, sort_key)
  timings.sort_by { |t| t[sort_key.to_sym] }
end

def print_results(all_timings, ems_timings, opts)
  columns        = [:start_time, :end_time, :total_time, :ems, :target_type, :target]
  column_lengths = [0, 0, 0, 0, 0, 0]

  print "Found #{all_timings.length} refreshes from #{ems_timings.keys.length} providers\n"

  # Calculate how much padding we need for each column
  sort_timings(all_timings, opts[:sort_by]).each do |timing|
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
  sort_timings(all_timings, opts[:sort_by]).each do |timing|
    column_lengths.each_with_index do |column_length, i|
      print "#{timing[columns[i]].to_s.ljust(column_length)} | "
    end
    print "\n"
  end
end

options, logfiles = parse_args(ARGV)

puts 'Processing file...'

all_timings = []
ems_timings = Hash.new { |k, v| k[v] = [] }
all_targets = Hash.new { |k, v| k[v] = [] }

logfiles.each do |logfile|
  MiqLoggerProcessor.new(logfile).each do |line|
    # Parse out the refresh target or refresh timings
    if (target_hash = parse_refresh_target(line))
      all_targets[target_hash[:ems]] << target_hash
    elsif (refresh_timings = parse_refresh_timings(line, all_targets))
      ems = refresh_timings[:ems]

      if filter(refresh_timings, options)
        ems_timings[ems] << refresh_timings
        all_timings << refresh_timings
      end
    end
  end
end

print_results(all_timings, ems_timings, options)
