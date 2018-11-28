#!/usr/bin/env ruby
RAILS_ROOT = File.expand_path(File.join(__dir__, %w(.. ..)))

require 'manageiq-gems-pending'
require 'miq_logger_processor'
require 'active_support/core_ext/enumerable' # Pull in Enumerable sum method
require 'more_core_extensions/core_ext/array'
require 'optimist'
require 'time'

def parse_args(argv)
  logfiles = []

  opts = Optimist.options do
    banner <<-EOS
Parse EMS Refreshes from a set of evm.log files and filter on a set of
provided conditions.

Usage:
  ruby ems_refresh_timings.rb [OPTION]... <FILE>...

Options:
EOS
    opt :sort_by, 'Column to sort by, options are start_time, end_time, '\
                  'duration, ems, target_type, and target',
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
    refresh_target = {
      :target      => "unknown",
      :target_type => "unknown"
    } if refresh_target.nil?

    # Add other useful information to the refresh timings
    refresh_timings[:ems]         = ems
    refresh_timings[:end_time]    = Time.parse(line.time + ' UTC').utc
    refresh_timings[:duration]    = refresh_timings[:total_time] || refresh_timings[:ems_refresh]
    refresh_timings[:start_time]  = refresh_timings[:end_time] - refresh_timings[:duration]
    refresh_timings[:target]      = refresh_target[:target]
    refresh_timings[:target_type] = refresh_target[:target_type]

    refresh_timings
  end
end

def sort_timings(timings, sort_key)
  timings.sort_by { |t| t[sort_key.to_sym] }
end

def print_results(all_timings, opts)
  columns = [:start_time, :end_time, :duration, :ems, :target_type, :target]
  puts sort_timings(all_timings, opts[:sort_by]).tableize(:columns => columns)
end

def mean(array)
  array.sum.to_f / array.length
end

def print_stats(timings)
  timings.each do |type, values|
    puts "\nAverage refresh time per #{type}"

    durations = []
    values.each do |key, timing|
      durations << {
        type.to_sym => key,
        :duration   => mean(timing.collect { |t| t[:duration] })
      }
    end

    puts durations.tableize(:columns => [type.to_sym, :duration])
  end
end

options, logfiles = parse_args(ARGV)

puts 'Processing file...'

all_timings = []
all_targets = Hash.new { |k, v| k[v] = [] }
timings     = {
  :ems         => Hash.new { |k, v| k[v] = [] },
  :target      => Hash.new { |k, v| k[v] = [] },
  :target_type => Hash.new { |k, v| k[v] = [] }
}

logfiles.each do |logfile|
  MiqLoggerProcessor.new(logfile).each do |line|
    # Parse out the refresh target or refresh timings
    if (target_hash = parse_refresh_target(line))
      all_targets[target_hash[:ems]] << target_hash
    elsif (refresh_timings = parse_refresh_timings(line, all_targets))
      ems         = refresh_timings[:ems]
      target      = refresh_timings[:target]
      target_type = refresh_timings[:target_type]

      if filter(refresh_timings, options)
        all_timings << refresh_timings
        timings[:ems][ems] << refresh_timings
        timings[:target][target] << refresh_timings
        timings[:target_type][target_type] << refresh_timings
      end
    end
  end
end

puts "Found #{all_timings.length} refreshes from #{timings[:ems].keys.length} providers"
unless all_timings.empty?
  print_results(all_timings, options)
  print_stats(timings)
end
