#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require "optimist"

opts = Optimist.options do
  opt :ems_id, "The ID of the ExtManagementSystem to reconnect VMs for", :type => :integer
  opt :ems_name, "The name of the ExtManagementSystem to reconnect VMs for", :type => :string
  opt :dry_run, "Just print out what would be done without modifying anything", :type => :boolean, :default => true
  opt :page_size, "How many records to delete at a time", :type => :integer, :default => 100
end

if opts[:ems_id].nil? && opts[:ems_name].nil?
  Optimist.die :ems_id, "Must pass either --ems-id or --ems-name"
end

ems = if opts[:ems_id].present?
        ExtManagementSystem.find_by(:id => opts[:ems_id])
      else
        ExtManagementSystem.find_by(:name => opts[:ems_name])
      end

if ems.nil?
  print "Failed to find EMS [#{opts.key?(:ems_id) ? opts[:ems_id] : opts[:ems_name]}]"
  exit
end

# Find all duplicate guest devices (having the same hardware_id + uid_ems)
duplicate_guest_devices = GuestDevice.where(:hardware => ems.host_hardwares)
                                     .group_by { |guest_device| [guest_device.hardware_id, guest_device.uid_ems] }
                                     .select   { |(_hardware_id, _uid_ems), guest_devices| guest_devices.count > 1 }

guest_devices_to_delete = duplicate_guest_devices.flat_map do |(_hardware_id, _uid_ems), guest_devices|
  # Pick the oldest guest_device to keep
  guest_devices.sort_by(&:id)[1..-1].map(&:id)
end

puts "Found #{guest_devices_to_delete.count} duplicate Guest Devices..."

if opts[:dry_run]
  puts "**** This is a dry-run, nothing will be updated! ****"
else
  puts "**** THIS WILL MODIFY YOUR DATABASE ****"
  puts "     Press Enter to Continue: "
  STDIN.getc
end

return if opts[:dry_run]

associations = %i[has_one has_many].flat_map { |assoc| GuestDevice.reflect_on_all_associations(assoc) }
dependents   = associations.select { |assoc| assoc.options[:dependent].present? }

total_slices = (guest_devices_to_delete.count / opts[:page_size].to_f).ceil
guest_devices_to_delete.each_slice(opts[:page_size]).with_index do |slice, index|
  puts "Destroying slice #{index + 1} of #{total_slices}..."
  GuestDevice.delete(slice)

  dependents.each do |assoc|
    delete_meth = assoc.options[:dependent]
    foreign_key = assoc.join_keys.key

    if %i[delete destroy].include?(delete_meth)
      assoc.klass.where(foreign_key => slice).send("#{delete_meth}_all")
    elsif delete_meth == :nullify
      assoc.klass.where(foreign_key => slice).update_all(foreign_key => nil)
    else
      assoc.klass.where(foreign_key => slice).each(&delete_meth)
    end
  end

  puts "Destroying slice #{index + 1} of #{total_slices}...Complete"
end

puts "Destroyed #{guest_devices_to_delete.count} duplicate Guest Devices"
