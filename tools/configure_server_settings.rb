#!/usr/bin/env ruby
require File.expand_path("../config/environment", __dir__)
require 'trollop'

opts = Trollop.options(ARGV) do
  banner "USAGE:   #{__FILE__} -s <server id> -p <settings path separated by a /> -v <new value>\n" \
         "Example: #{__FILE__} -d -s 1 -p reporting/history/keep_reports -v 42\n" \
         "Example: #{__FILE__} -s 1 -p workers/worker_base/queue_worker_base/ems_metrics_collector_worker/defaults/count -v 4 -i"

  opt :dry_run,  "Dry Run",                            :short => "d"
  opt :serverid, "Server Id",                          :short => "s", :type => :integer, :required => true
  opt :path,     "Path within advanced settings hash", :short => "p", :type => :string, :required => true
  opt :value,    "New Value for setting",              :short => "v", :type => :string, :required => true
  opt :integer,  "Value Provided is an Integer",       :short => "i", :type => :boolean, :default => false

  depends :path, :serverid, :value
end

puts opts.inspect

# Grab the value that we have set
if opts[:integer]
  newval = opts[:value].to_i
else
  newval = opts[:value]
end

server = MiqServer.where(:id => opts[:serverid]).take
unless server
  puts "Unable to find server with id [#{opts[:serverid]}]"
  exit 1
end

settings = server.get_config("vmdb")

path = settings.config
keys = opts[:path].split("/")
key = keys.pop.to_sym
keys.each { |p| path = path[p.to_sym] }

puts "Setting [#{opts[:path]}], old value: [#{path[key]}], new value: [#{opts[:value]}]"
path[key] = newval

valid, errors = VMDB::Config::Validator.new(settings).validate
unless valid
  puts "ERROR: Configuration is invalid:"
  errors.each { |k, v| puts "\t#{k}: #{v}" }
  exit 1
end

if opts[:dry_run]
  puts "Dry run, no updates have been made"
else
  server.set_config(settings)
  server.save!

  puts "Done"
end
