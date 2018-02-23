#!/usr/bin/env ruby
require File.expand_path("../config/environment", __dir__)
require 'trollop'

opts = Trollop.options(ARGV) do
  banner "USAGE:   #{__FILE__} -s <server id> -p <settings path separated by a /> -v <new value>\n" \
         "Example: #{__FILE__} -d -s 1 -p reporting/history/keep_reports -v 42"

  opt :dry_run,  "Dry Run",                            :short => "d"
  opt :serverid, "Server Id",                          :short => "s", :default => 0
  opt :path,     "Path within advanced settings hash", :short => "p", :default => ""
  opt :value,    "New value for setting",              :short => "v", :default => ""
end

puts opts.inspect

Trollop.die :serverid, "is required" unless opts[:serverid_given]
Trollop.die :path,     "is required" unless opts[:path_given]
Trollop.die :value,    "is required" unless opts[:value_given]

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
opts[:value] = opts[:value].to_i if !!(opts[:value].match /^(\d)+$/ )

puts "Setting [#{opts[:path]}], old value: [#{path[key]}](#{path[key].class}), new value: [#{opts[:value]}](#{opts[:value].class})"
path[key] = opts[:value]

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
