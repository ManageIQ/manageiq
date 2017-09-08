#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

if ARGV.length != 1
  puts "Usage: rails runner #{$0} time_profile_id"
  exit 1
end
tp_id = MiqRegion.uncompress_id(ARGV.first)

def log(msg)
  $log.info("MIQ(#{__FILE__}) #{msg}")
  puts msg
end

log("Removing performance records for time profile #{tp_id}...")
TimeProfile.find(tp_id).destroy_metric_rollups
log("Removing performance records for time profile #{tp_id}...Complete")
