require_relative '../../bundler_setup'
require_relative '../rhevm_api'
require 'pp'

RHEVM_SERVER        = raise "please define RHEVM_SERVER"
RHEVM_PORT          = 443
RHEVM_DOMAIN        = raise "please define RHEVM_DOMAIN"
RHEVM_USERNAME      = raise "please define RHEVM_USERNAME"
RHEVM_PASSWORD      = raise "please define RHEVM_PASSWORD"
VM_NAME             = raise "please define VM_NAME"
destination_template_name = "bd-clone-template"

rhevm = RhevmService.new(
          :server   => RHEVM_SERVER,
          :port     => RHEVM_PORT,
          :domain   => RHEVM_DOMAIN,
          :username => RHEVM_USERNAME,
          :password => RHEVM_PASSWORD)

source  = RhevmVm.find_by_name(rhevm, VM_NAME)

unless source.nil?
  puts "VM"
  pp source.attributes
end

destination = source.create_template(:name => destination_template_name)

puts "Created Template"; pp destination
destination = RhevmTemplate.find_by_name(rhevm, destination_template_name)
puts "Found Template"; pp destination
