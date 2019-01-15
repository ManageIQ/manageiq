#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'optimist'

MODES = %w(count purge)

ARGV.shift if ARGV[0] == '--' # if invoked with rails runner
opts = Optimist.options do
  banner "Purge metrics records.\n\nUsage: ruby #{$0} [options]\n\nOptions:\n\t"
  opt :mode,     "Mode (#{MODES.join(", ")})", :default => "count"
  opt :realtime, "Realtime range", :default => "4.hours"
  opt :hourly,   "Hourly range",   :default => "6.months"
  opt :daily,    "Daily range",    :default => "6.months"
  opt :window,   "Window of records to delete at once", :default => 10000
  opt :limit,    "Total number of records to delete per method"
end
Optimist.die :mode,     "must be one of #{MODES.join(", ")}" unless MODES.include?(opts[:mode])
Optimist.die :realtime, "must be a number with method (e.g. 4.hours)"  unless opts[:realtime].number_with_method?
Optimist.die :hourly,   "must be a number with method (e.g. 6.months)" unless opts[:hourly].number_with_method?
Optimist.die :daily,    "must be a number with method (e.g. 6.months)" unless opts[:daily].number_with_method?
Optimist.die :window,   "must be a number greater than 0" if opts[:window] <= 0

def log(msg)
  $log.info("MIQ(#{__FILE__}) #{msg}")
  puts msg
end

formatter = Class.new.extend(ActionView::Helpers::NumberHelper)

log("Purge Counts")
dates = {}
counts = {}
%w(realtime hourly daily).each do |interval|
  dates[interval]  = opts[interval.to_sym].to_i_with_method.seconds.ago.utc
  counts[interval] = Metric::Purging.purge_count(dates[interval], interval)
  log("  #{"#{interval.titleize}:".ljust(9)} #{formatter.number_with_delimiter(counts[interval])}")
end
puts

exit if opts[:mode] != "purge"

log("Purging...")
require 'ruby-progressbar'
%w(realtime hourly daily).each do |interval|
  pbar = ProgressBar.create(:title => interval.titleize, :total => counts[interval], :autofinish => false)
  if counts[interval] > 0
    Metric::Purging.purge(dates[interval], interval, opts[:window], opts[:limit]) do |count, _|
      pbar.progress += count
    end
  end
  pbar.finish
end
log("Purging...Complete")
