#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require "optimist"

opts = Optimist.options do
  opt :ems_id, "The ID of the ExtManagementSystem to reconnect VMs for", :type => :integer
  opt :ems_name, "The name of the ExtManagementSystem to reconnect VMs for", :type => :string
  opt :by, "Property to treat as unique, defaults to :uid_ems", :type => :string, :default => "uid_ems"
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

# Find all VMs which match the unique key
vms_index = VmOrTemplate.where(opts[:by] => ems.vms_and_templates.pluck(opts[:by])).group_by { |vm| vm.send(opts[:by]) }

# Select where there are exactly two with the same unique property, one archived and one active
duplicate_vms = vms_index.select { |_by, vms| vms.count == 2 && vms.select(&:active).count == 1 }
puts "Found #{duplicate_vms.count} duplicate VMs..."

if opts[:dry_run]
  puts "**** This is a dry-run, nothing will be updated! ****"
else
  puts "**** THIS WILL MODIFY YOUR VMS ****"
  puts "     Press Enter to Continue: "
  STDIN.getc
end

activated_vms = duplicate_vms.map do |_by, vms|
  active_vms, inactive_vms = vms.partition(&:active)

  # There should only be one of each
  active_vm   = active_vms.first
  inactive_vm = inactive_vms.first

  next if active_vm.nil? || inactive_vm.nil?
  next if active_vm.created_on < inactive_vm.created_on # Always pick the older VM

  # Disconnect the new VM and activate the old VM
  puts "Disconnecting Vm [#{active_vm.name}] id [#{active_vm.id}] uid_ems [#{active_vm.uid_ems}] ems_ref [#{active_vm.ems_ref}]"
  active_vm.disconnect_inv unless opts[:dry_run]

  puts "Activating Vm    [#{inactive_vm.name}] id [#{inactive_vm.id}] uid_ems [#{inactive_vm.uid_ems}] ems_ref [#{inactive_vm.ems_ref}]"
  inactive_vm.update!(:ems_id => ems_id, :uid_ems => active_vm.uid_ems, :ems_ref => active_vm.ems_ref) unless opts[:dry_run]

  inactive_vm
end.compact

puts "Activated #{activated_vms.count} VMs:\n#{activated_vms.map(&:name).join(", ")}"
