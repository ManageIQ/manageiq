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
source_template_name        = raise "define source_template_name"
destination_vm_name         = raise "define destination_vm_name"
destination_storage_domain  = raise "define destination_storage_domain"

rhevm = RhevmService.new(
          :server   => RHEVM_SERVER,
          :port     => RHEVM_PORT,
          :domain   => RHEVM_DOMAIN,
          :username => RHEVM_USERNAME,
          :password => RHEVM_PASSWORD)


source = RhevmTemplate.find_by_name(rhevm, source_template_name)

unless source.nil?
  puts "Template"
  pp source.attributes
end

destination = source.create_vm(
  :name         => destination_vm_name,
  :clone_type   => :skeletal,
  :cluster      => RhevmCluster.find_by_id(rhevm, source[:cluster][:id]),
  :sparse       => :false,
  :storage      => RhevmStorageDomain.find_by_name(rhevm, destination_storage_domain)[:href],
  )

puts "Created VM"; pp destination
destination = RhevmVm.find_by_name(rhevm, destination_vm_name)
puts "Found VM"; pp destination
