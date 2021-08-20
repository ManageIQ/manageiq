#!/usr/bin/env ruby

require 'dalli'
require 'benchmark'

server_host    = ENV.fetch("MEMCACHED_SERVICE_HOST", "localhost")
server_port    = ENV.fetch("MEMCACHED_SERVICE_PORT", "11211")
server_address = "#{server_host}:#{server_port}"

begin
  client = Dalli::Client.new(server_address)
  avg = 10.times.map { Benchmark.realtime { client.get("test") } }.inject(:+) / 10.0

  puts "Average: #{avg.round(8)} seconds"
rescue => err
  puts "Failed: #{err}"
end
