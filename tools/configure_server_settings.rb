#!/usr/bin/env ruby
require File.expand_path("../config/environment", __dir__)
require 'trollop'

TYPES = %w{ string integer boolean symbol float }

opts = Trollop.options(ARGV) do
  banner "USAGE:   #{__FILE__} -s <server id> -p <settings path separated by a /> -v <new value>\n" \
         "Example (String): #{__FILE__} -d -s 1 -p reporting/history/keep_reports -v 42\n" \
         "Example (Integer): #{__FILE__} -s 1 -p workers/worker_base/queue_worker_base/ems_metrics_collector_worker/defaults/count -v 1 -t integer\n" \
         "Example (Boolean): #{__FILE__} -s 1 -p ui/mark_translated_strings -v true -t boolean\n" \
         "Example (Symbol): #{__FILE__} -s 1 -p workers/worker_base/queue_worker_base/ems_metrics_collector_worker/defaults/poll_method -v :escalate -t symbol\n" \
         "Example (Float): #{__FILE__} -s 1 -p capacity/profile/1/vcpu_commitment_ratio -v 1.5 -t float"

  opt :dry_run,  "Dry Run",                                  :short => "d"
  opt :serverid, "Server Id",                                :short => "s", :type => :integer, :required => true
  opt :path,     "Path within advanced settings hash",       :short => "p", :type => :string,  :required => true
  opt :value,    "New Value for setting",                    :short => "v", :type => :string,  :required => true
  opt :force,    "Force change value regardless of type",    :short => "f", :type => :boolean, :default  => false
  opt :type,     "Type of value provided, #{TYPES.inspect}", :short => "t", :type => :string,  :default  => "string"
end

puts opts.inspect

Trollop.die :serverid, "is required" unless opts[:serverid_given]
Trollop.die :path,     "is required" unless opts[:path_given]
Trollop.die :value,    "is required" unless opts[:value_given]
Trollop.die :type,     "must be one of #{TYPES.inspect}" unless TYPES.include?(opts[:type])

# Grab the value that we have set and translate to appropriate var class
case opts[:type]
when "integer"
  newval = opts[:value].to_i
when "boolean"
  if opts[:value].downcase == "true"
    newval = true
  elsif opts[:value].downcase == "false"
    newval = false
  end
when "symbol"
  newval = opts[:value].to_sym
when "float"
  newval = opts[:value].to_f
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

# allow user to escape if the new value's class is not the same as the original,
# such as setting a String where it was previously an Integer
if opts[:force]
  puts "Change [#{opts[:path]}], old class: [#{path[key].class}], new class: [#{newval.class}]"
elsif path[key] && path[key].class != newval.class
  STDERR.puts "The new value's class #{newval.class} does not match the prior one's #{path[key].class}.  Use -f to force update, this may break things!"
  exit 1
end

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
