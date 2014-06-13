# Push the lib directory onto the load path
$:.push(File.expand_path(File.join(File.dirname(__FILE__), '..', '..')))

require_relative '../../bundler_setup'
require_relative '../rhevm_api'

RHEVM_SERVER        = raise "please define RHEVM_SERVER"
RHEVM_PORT          = 443
RHEVM_DOMAIN        = raise "please define RHEVM_DOMAIN"
RHEVM_USERNAME      = raise "please define RHEVM_USERNAME"
RHEVM_PASSWORD      = raise "please define RHEVM_PASSWORD"
VM_NAME              = raise "please define VM_NAME"

rhevm = RhevmService.new(
          :server   => RHEVM_MAHWAH_SERVER,
          :port     => RHEVM_MAHWAH_PORT,
          :domain   => RHEVM_DOMAIN,
          :username => RHEVM_USERNAME,
          :password => RHEVM_PASSWORD)

hosts = RhevmHost.all(rhevm)
host  = hosts.first

vm = RhevmVm.find_by_name(rhevm, VM_NAME)
puts "VM Placement Policy: #{vm[:placement_policy].inspect}"

puts "Setting Host Affinity to: #{host[:name].inspect} with ID=#{host[:id].inspect}"
vm.host_affinity = host

vm = RhevmVm.find_by_name(rhevm, VM_NAME)
puts "VM Placement Policy: #{vm[:placement_policy].inspect}"

puts "Unsetting Host Affinity"
vm.host_affinity = nil

vm = RhevmVm.find_by_name(rhevm, VM_NAME)
puts "VM Placement Policy: #{vm[:placement_policy].inspect}"
