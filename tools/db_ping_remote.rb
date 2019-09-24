#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'io/console'

def usage
  <<-USAGE
    Usage:
      `ruby tools/db_ping_remote.rb <host> <port> <username> [database] [adapter]`

      host, port, username, and password are required
      database and adapter will be defaulted to the local configuration if not provided
  USAGE
end

host, port, username, database, adapter = ARGV
unless host && port && username
  puts usage
  exit 1
end

puts "Enter the password for database user #{username} on host #{host}"
print "Password: "
password = STDIN.noecho(&:gets).chomp
puts ""

total = 0
5.times do
  ping = MiqRegionRemote.db_ping(host, port, username, password, database, adapter)
  puts "%.6f ms" % ping
  total += ping
  sleep 1
end
puts
puts "Average: %.6f ms" % (total / 5)
