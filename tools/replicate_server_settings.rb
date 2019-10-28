#!/usr/bin/env ruby
require File.expand_path("../config/environment", __dir__)
$LOAD_PATH << Rails.root.join("tools").to_s
require 'optimist'
require 'server_settings_replicator/server_settings_replicator'

opts = Optimist.options(ARGV) do
  banner "USAGE:   #{__FILE__} -s <server id> -p <path/to/the/settings> \n" \
         "Example: #{__FILE__} -d -s 1 -p ems/ems_amazon/additional_instance_types"

  opt :dry_run,  "Dry Run",                                                :short => "d"
  opt :serverid, "Replicating source server Id (default: current server)", :short => "s", :type => :integer
  opt :path,     "Replicating source path within advanced settings hash",  :short => "p", :default => ""
end

Optimist.die :path, "is required" unless opts[:path_given]

server = opts[:serverid_given] ? MiqServer.find(opts[:serverid]) : MiqServer.my_server
ServerSettingsReplicator.replicate(server, opts[:path], opts[:dry_run])
