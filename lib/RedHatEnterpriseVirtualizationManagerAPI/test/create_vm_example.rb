# Push the lib directory onto the load path
$:.push(File.expand_path(File.join(File.dirname(__FILE__), '..', '..')))

require_relative '../../bundler_setup'
require_relative '../rhevm_api'
require 'pp'

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

vm = RhevmVm.find_by_name(rhevm, VM_NAME)

unless vm.nil?
  puts "VM"
  pp vm.attributes
end

unless vm.nil?
  vm_id = vm[:id]
puts  "DELETING VM"
  vm.destroy
  loop do
    vm = RhevmVm.find_by_id(rhevm, vm_id)
    break if vm.nil?
puts  "VM still exists"
    sleep 1.0
  end
end

pxe_template = RhevmTemplate.find_by_name(rhevm, "pxe-template")
puts "TEMPLATE:"; pp pxe_template.attributes
cluster      = RhevmCluster.find_by_name(rhevm, "Cluster2")

vm = pxe_template.clone_to_vm_via_blank_template(
           :name     => VM_NAME,
           :cluster  => cluster,
           )
puts "Created VM"; pp vm
vm = RhevmVm.find_by_name(rhevm, VM_NAME)
puts "Found VM"; pp vm
