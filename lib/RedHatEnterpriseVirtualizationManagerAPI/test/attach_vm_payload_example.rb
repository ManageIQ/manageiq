# Push the lib directory onto the load path
$:.push(File.expand_path(File.join(File.dirname(__FILE__), '..', '..')))

require_relative '../../bundler_setup'
require_relative '../rhevm_api'
require 'pp'

RHEVM_SERVER    = raise "please define RHEVM_SERVER"
RHEVM_PORT      = 443
RHEVM_DOMAIN    = raise "please define RHEVM_DOMAIN"
RHEVM_USERNAME  = raise "please define RHEVM_USERNAME"
RHEVM_PASSWORD  = raise "please define RHEVM_PASSWORD"
VM_NAME         = "test_vm"
PAYLOAD         = {"test.file" => "test content"}

rhevm = RhevmService.new(
  :server   => RHEVM_SERVER,
  :domain   => RHEVM_DOMAIN,
  :username => RHEVM_USERNAME,
  :password => RHEVM_PASSWORD
)


puts "Finding VM..."
vm = RhevmVm.find_by_name(rhevm, VM_NAME)

puts "Found #{VM_NAME}" if vm

puts "Attaching floppy payload"
puts vm.attach_floppy(PAYLOAD)

puts
pp vm
