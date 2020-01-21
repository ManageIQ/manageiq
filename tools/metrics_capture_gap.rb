#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

if ARGV.length < 2 || ARGV.length > 3
  puts "Usage: rails runner #{$PROGRAM_NAME} start_date end_date [ems_id]"
  puts
  puts "  start_date and end_date must be in iso8601 format (e.g. 2010-02-15T00:00:00Z)."
  exit 1
end
start_date, end_date, ems_id = *ARGV

def log(msg)
  $log.info("MIQ(#{__FILE__}) #{msg}")
  puts msg
end

log("Queueing metrics capture for [#{start_date}..#{end_date}]...")
Metric::Capture.perf_capture_gap(Time.parse(start_date).utc, Time.parse(end_date).utc, nil, ems_id&.to_i)
log("Queueing metrics capture for [#{start_date}..#{end_date}]...Complete")
