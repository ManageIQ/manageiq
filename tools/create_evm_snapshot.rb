#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

def usage
  puts "Error: Must pass only one of the following:"
  puts "  --vm=<vm id>"
  puts "  --job=<job id>"
  puts
  puts "  ID values may be a comma separated list."
  exit 1
end

usage unless ARGV.join.strip =~ /--(vm|job) *=?([0-9, ]+)/

type = $1
ids  = $2.split(',').collect do |id|
  id.strip!
  id.blank? ? nil : id.to_i
end.compact.uniq

case type
when 'vm'
  vms = Vm.where(:id => ids)
  puts "Warning: Unable to find Vms for the following ids: #{ids - vms.collect(&:id)}" if ids.length != vms.length
  return if vms.empty?

  descs = []
  vms.each do
    descs << "Snapshot for scan job: #{SecureRandom.uuid}, EVM Server build: #{Vmdb::Appliance.BUILD}  Server Time: #{Time.now.utc.iso8601}"
  end
when 'job'
  jobs = Job.where(:id => ids)
  puts "Warning: Unable to find Jobs for the following ids: #{ids - jobs.collect(&:id)}" if ids.length != jobs.length
  return if jobs.empty?

  vms   = []
  descs = []
  jobs.each do |job|
    vms << Object.const_get(job.target_class).find(job.target_id)
    descs << "Snapshot for scan job: #{job.guid}, EVM Server build: #{Vmdb::Appliance.BUILD}  Server Time: #{Time.now.utc.iso8601}"
  end
else
  usage
end

vms.each_with_index do |vm, i|
  puts "Creating EVM snapshot for Vm with id #{vm.id}..."
  vm.ext_management_system.vm_create_evm_snapshot(vm, :desc => descs[i])
  puts "Creating EVM snapshot for Vm with id #{vm.id}...Complete"
end
