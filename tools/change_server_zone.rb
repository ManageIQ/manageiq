#!/usr/bin/env ruby
require File.expand_path("../config/environment", __dir__)

if ARGV.empty?
  puts "USAGE: #{__FILE__} serverid zone_name"
  exit 0
end

server_id, zone_name = ARGV

server = MiqServer.find_by(:id => server_id)
unless server
  puts "Unable to find server with id [#{server_id}]"
  exit 1
end

zone = Zone.find_by(:name => zone_name)
unless zone
  puts "Unable to find zone with name [#{zone_name}]"
  exit 1
end

server.zone = zone
server.save!

settings = server.settings
settings[:server][:zone] = zone.name
server.add_settings_for_resource(settings)

server.save!

puts "Configured server [#{server.id}] to be in zone [#{zone.name}]"
