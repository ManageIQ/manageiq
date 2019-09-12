#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require "optimist"

opts = Optimist.options do
  opt :ems_id, "The ID of the ExtManagementSystem to reconnect Hosts for", :type => :integer
  opt :ems_name, "The name of the ExtManagementSystem to reconnect Hosts for", :type => :string
  opt :by, "Property to treat as unique, defaults to :hostname", :type => :string, :default => "hostname"
  opt :dry_run, "Just print out what would be done without modifying anything", :type => :boolean, :default => true
end

if opts[:ems_id].nil? && opts[:ems_name].nil?
  Optimist.die :ems_id, "Must pass either --ems-id or --ems-name"
end

ems = if opts[:ems_id].present?
        ExtManagementSystem.find_by(:id => opts[:ems_id])
      else
        ExtManagementSystem.find_by(:name => opts[:ems_id])
      end

if ems.nil?
  print "Failed to find EMS [#{opts.key?(:ems_id) ? opts[:ems_id] : opts[:ems_name]}]"
  exit
end

ems_id = ems.id

# Find all Hosts which match the unique key
hosts_index = Host.where(opts[:by] => ems.hosts.pluck(opts[:by])).group_by { |host| host.send(opts[:by]) }

# Select where there are exactly two with the same unique property, one archived and one active
duplicate_hosts = hosts_index.select { |_by, hosts| hosts.count == 2 && hosts.select(&:has_active_ems?).count == 1 }
puts "Found #{duplicate_hosts.count} duplicate Hosts..."

if opts[:dry_run]
  puts "**** This is a dry-run, nothing will be updated! ****"
else
  puts "**** THIS WILL MODIFY YOUR HOSTS ****"
  puts "     Press Enter to Continue: "
  STDIN.getc
end

activated_hosts = duplicate_hosts.map do |_by, hosts|
  active_hosts, inactive_hosts = hosts.partition(&:has_active_ems?)

  # There should only be one of each
  active_host   = active_hosts.first
  inactive_host = inactive_hosts.first

  next if active_host.nil? || inactive_host.nil?
  next if active_host.created_on < inactive_host.created_on # Always pick the older Host

  # Disconnect the new Host and activate the old Host
  puts "Disconnecting Host [#{active_host.name}] id [#{active_host.id}] uid_ems [#{active_host.uid_ems}] ems_ref [#{active_host.ems_ref}]"
  active_host.disconnect_inv unless opts[:dry_run]

  puts "Activating Host    [#{inactive_host.name}] id [#{inactive_host.id}] uid_ems [#{inactive_host.uid_ems}] ems_ref [#{inactive_host.ems_ref}]"
  inactive_host.update!(:ems_id => ems_id, :uid_ems => active_host.uid_ems, :ems_ref => active_host.ems_ref) unless opts[:dry_run]

  inactive_host
end.compact

puts "Activated #{activated_hosts.count} Hosts:\n#{activated_hosts.map(&:name).join(", ")}"
