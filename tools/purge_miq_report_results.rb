#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'optimist'

MODES = %w(count purge)

ARGV.shift if ARGV[0] == '--' # if invoked with rails runner
opts = Optimist.options do
  banner "Purge miq_report_results records.\n\nUsage: ruby #{$0} [options]\n\nOptions:\n\t"
  opt :mode,      "Mode (#{MODES.join(", ")})",          :default => "count"
  opt :window,    "Window of records to delete at once", :default => 100
  opt :date,      "Range of reports to keep by date (default: VMDB configuration)",     :type => :string
  opt :remaining, "Number of results to keep per report (default: VMDB configuration)", :type => :int
end
Optimist.die :mode,   "must be one of #{MODES.join(", ")}" unless MODES.include?(opts[:mode])
Optimist.die :window, "must be a number greater than 0"    if opts[:window] <= 0
if opts[:remaining_given]
  Optimist.die :remaining, "must be a number greater than 0" if opts[:remaining] <= 0
  purge_mode  = :remaining
  purge_value = opts[:remaining]
elsif opts[:date_given]
  Optimist.die :date, "must be a number with method (e.g. 6.months)" unless opts[:date].number_with_method?
  purge_mode  = :date
  purge_value = opts[:date].to_i_with_method.seconds.ago.utc
else
  purge_mode, purge_value = MiqReportResult.purge_mode_and_value
end

def log(msg)
  $log.info("MIQ(#{__FILE__}) #{msg}")
  puts msg
end

formatter = Class.new.extend(ActionView::Helpers::NumberHelper)

msg = case purge_mode
      when :remaining then "last #{purge_value} results"
      when :date then      "[#{purge_value.iso8601}]"
      end
log("Executing in #{opts[:mode]} mode for report results older than #{msg}")

count = MiqReportResult.purge_count(purge_mode, purge_value)
log("Purge Count: #{formatter.number_with_delimiter(count)}")
puts

exit if opts[:mode] != "purge"

log("Purging...")
require 'ruby-progressbar'
pbar = ProgressBar.create(:title => "Purging", :total => count, :autofinish => false)

if count > 0
  MiqReportResult.purge(purge_mode, purge_value, opts[:window]) do |increment, _|
    pbar.progress += increment
  end
end

pbar.finish
log("Purging...Complete")
