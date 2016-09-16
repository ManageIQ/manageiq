#!/usr/bin/env ruby
require File.expand_path("../config/environment", __dir__)

if ARGV.empty?
  puts "USAGE:   #{__FILE__} server_id settings_path_separated_by_a_/ value [settings_path_separated_by_a_/ value]"
  puts "Example: #{__FILE__} 2 smtp/authentication plain smtp/host gt123"

  exit 0
end

server_id = ARGV[0]
new_settings = ARGV[1..-1]

server = MiqServer.where(:id => server_id).take
unless server
  puts "Unable to find server with id [#{server_id}]"
  exit 1
end

settings = server.get_config("vmdb")

new_settings.each_slice(2) do |k, v|
  path = settings.config
  keys = k.split("/")
  key = keys.pop.to_sym
  keys.each { |p| path = path[p.to_sym] }

  puts "Setting [#{k}], old value: [#{path[key]}], new value: [#{v}]"
  path[key] = v
end

valid, errors = VMDB::Config::Validator.new(settings).validate
unless valid
  puts "ERROR: Configuration is invalid:"
  errors.each { |k, v| puts "\t#{k}: #{v}" }
  exit 1
end

server.set_config(settings)
server.save!

puts "Done"
