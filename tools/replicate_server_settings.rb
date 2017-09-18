#!/usr/bin/env ruby
require File.expand_path("../config/environment", __dir__)
require 'trollop'

opts = Trollop.options(ARGV) do
  banner "USAGE:   #{__FILE__} -s <server id> -p <path/to/the/settings> \n" \
         "Example: #{__FILE__} -d -s 1 -p ems/ems_amazon/additional_instance_types"

  opt :dry_run,  "Dry Run",                                                :short => "d"
  opt :serverid, "Replicating source server Id (default: current server)", :short => "s"
  opt :path,     "Replicating source path within advanced settings hash",  :short => "p", :default => ""
end

puts opts.inspect
Trollop.die :path, "is required" unless opts[:path_given]

def replicate(opts)
  server = opts[:serverid] ? MiqServer.find(opts[:serverid]) : MiqServer.my_server
  path = opts[:path].split("/").map(&:to_sym)

  # all servers except source
  target_servers = MiqServer.where.not(:id => server.id)
  settings = construct_setting_tree(path, server.settings_for_resource.fetch_path(path))

  puts "Replicating from server id=#{server.id}, path=#{opts[:path]} to #{target_servers.count} servers"
  puts "Settings: #{settings}"

  if opts[:dry_run]
    puts "Dry run, no updates have been made"
  else
    copy_to(target_servers, settings)
  end
  puts "Done"
end

def construct_setting_tree(path, values)
  # construct the partial tree containing the target values
  path.reverse.inject(values) { |m, e| {e => m} }
end

def copy_to(target_servers, target_settings)
  target_servers.each do |target|
    puts " - replicating to server id=#{target.id}..."
    target.add_settings_for_resource(target_settings)
    target.save!
  end
end

replicate(opts)
