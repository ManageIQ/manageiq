#!/usr/bin/env ruby
require 'bundler/setup'
require 'optimist'

TYPES = %w(string integer boolean symbol float array).freeze

opts = Optimist.options(ARGV) do
  banner "USAGE:   #{__FILE__} -s <server id> -p <settings path separated by a /> -v <new value>\n" \
         "Example (String):  #{__FILE__} -s 1 -p reporting/history/keep_reports -v 3.months\n" \
         "Example (Integer): #{__FILE__} -s 1 -p workers/worker_base/queue_worker_base/ems_metrics_collector_worker/defaults/count -v 1 -t integer\n" \
         "Example (Boolean): #{__FILE__} -s 1 -p ui/mark_translated_strings -v true -t boolean\n" \
         "Example (Symbol):  #{__FILE__} -s 1 -p workers/worker_base/queue_worker_base/ems_metrics_collector_worker/defaults/poll_method -v escalate -t symbol\n" \
         "Example (Float):   #{__FILE__} -s 1 -p capacity/profile/1/vcpu_commitment_ratio -v 1.5 -t float" \

  opt :dry_run,         "Dry Run",                                  :short => "d"
  opt :serverid,        "Server Id",                                :short => "s", :type => :integer, :required => false
  opt :path,            "Path within advanced settings hash",       :short => "p", :type => :string,  :required => true
  opt :value,           "New Value for setting",                    :short => "v", :type => :string,  :required => true
  opt :force,           "Force change value regardless of type",    :short => "f", :type => :boolean, :default  => false
  opt :type,            "Type of value provided, #{TYPES.inspect}", :short => "t", :type => :string,  :default  => "string"
  opt :all_servers,     "Set setting once for all servers",         :short => "a", :type => :boolean, :default  => false
end

puts opts.inspect

Optimist.die :serverid, "is required" unless opts[:serverid_given] || opts[:all_servers]
Optimist.die :path,     "is required" unless opts[:path_given]
Optimist.die :value,    "is required" unless opts[:value_given]
Optimist.die :type,     "must be one of #{TYPES.inspect}" unless TYPES.include?(opts[:type])

# Grab the value that we have set and translate to appropriate var class
newval =
  case opts[:type]
  when "string"
    opts[:value]
  when "integer"
    opts[:value].to_i
  when "boolean"
    if opts[:value].downcase == "true"
      true
    elsif opts[:value].downcase == "false"
      false
    end
  when "symbol"
    opts[:value].to_sym
  when "float"
    opts[:value].to_f
  when "array"
    opts[:value].split(",")
  end

# load rails after checking CLI args so we can report args errors as fast as possible
require File.expand_path("../config/environment", __dir__)

def boolean?(value)
  value.kind_of?(TrueClass) || value.kind_of?(FalseClass)
end

def types_valid?(old_val, new_val)
  if boolean?(old_val)
    boolean?(new_val)
  else
    new_val.kind_of?(old_val.class)
  end
end

server_list = opts[:all_servers] ? MiqServer.all : MiqServer.where(:id => opts[:serverid])
if server_list.empty?
  puts "Unable to find server with id [#{opts[:serverid]}]"
  exit 1
end

server_list.each do |server|
  settings = server.settings
  server_id = server.id
  path = settings
  keys = opts[:path].split("/")
  key = keys.pop.to_sym
  keys.each { |p| path = path[p.to_sym] }

  # allow user to escape if the new value's class is not the same as the original,
  # such as setting a String where it was previously an Integer
  if opts[:force]
    puts "Change [#{opts[:path]}], old class: [#{path[key].class}], new class: [#{newval.class}]"
  elsif path[key] && !types_valid?(path[key], newval)
    STDERR.puts "The new value's class #{newval.class} does not match the prior one's #{path[key].class}. Use -t to specify the type for the provided value. Use -f to force changing this value. Note, -f may break things! See -h for examples."
    exit 1
  end

  puts "Setting [#{opts[:path]}], old value: [#{path[key]}], new value: [#{newval}]"
  path[key] = newval

  valid, errors = Vmdb::Settings.validate(settings)
  unless valid
    puts "ERROR: Configuration is invalid:"
    errors.each { |k, v| puts "\t#{k}: #{v}" }
    exit 1
  end

  if opts[:dry_run]
    puts "Dry run, no updates to server #{server_id} have been made"
  else
    puts " - replicating to server id=#{server_id}..."
    server.add_settings_for_resource(settings)
    server.save!
    puts "Done"
  end
end
