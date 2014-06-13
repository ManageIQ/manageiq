# Push the lib directory onto the load path
$:.push(File.expand_path(File.join(File.dirname(__FILE__), '..', '..')))

require_relative '../../bundler_setup'
require_relative '../rhevm_api'

RHEVM_SERVER        = raise "please define RHEVM_SERVER"
RHEVM_PORT          = 443
RHEVM_DOMAIN        = raise "please define RHEVM_DOMAIN"
RHEVM_USERNAME      = raise "please define RHEVM_USERNAME"
RHEVM_PASSWORD      = raise "please define RHEVM_PASSWORD"
VM_NAME             = raise "please define VM_NAME"

rhevm = RhevmService.new(
          :server   => RHEVM_SERVER,
          :port     => RHEVM_PORT,
          :domain   => RHEVM_DOMAIN,
          :username => RHEVM_USERNAME,
          :password => RHEVM_PASSWORD)

sd1 = RhevmStorageDomain.find_by_name(rhevm, "MTCRHDS001")
puts "SD1: #{sd1.inspect}"
sd2 = RhevmStorageDomain.find_by_name(rhevm, "MTCRHDS002")
puts "SD2: #{sd2.inspect}"

vm = RhevmVm.find_by_name(rhevm, VM_NAME)
puts "VM: #{vm.inspect}"

disks = vm.disks
puts "DISKS: #{disks.inspect}"

disk = disks.first
puts "DISK: #{disk.inspect}"
puts "DISK SD: #{disk[:storage_domains].inspect}"
sd_id = disk[:storage_domains].first[:id]
puts "DISK SD ID: #{sd_id.inspect}"

sd = RhevmStorageDomain.find_by_id(rhevm, sd_id)
puts "DISK SD: #{sd.inspect}"

if sd[:id] == sd1[:id]
  puts "SD1 MATCH"
  target_sd = sd2
elsif sd[:id] == sd2[:id]
  puts "SD2 MATCH"
  target_sd = sd1
else
  puts "MISMATCH"
  target_sd = nil
end

puts "MOVING VM from #{sd[:name]} => #{target_sd[:name]}"
action = vm.move(target_sd)
puts "ACTION: #{action.inspect}"

loop do
  status = rhevm.status(action)
  puts "STATUS: #{status.inspect}"
  break if status == 'complete'
  sleep 1
end
