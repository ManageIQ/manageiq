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
source_template_name  = "bd-clone-template"
destination_vm_name   = "bd-linked-clone-from-template"

rhevm = RhevmService.new(
          :server   => RHEVM_MAHWAH_SERVER,
          :port     => RHEVM_MAHWAH_PORT,
          :domain   => RHEVM_DOMAIN,
          :username => RHEVM_USERNAME,
          :password => RHEVM_PASSWORD)


source = RhevmTemplate.find_by_name(rhevm, source_template_name)

unless source.nil?
  puts "Template"
  pp source.attributes
end

destination = source.create_vm(
  :clone_type => :linked,
  :name       => destination_vm_name,
  :cluster    => RhevmCluster.find_by_id(rhevm, source[:cluster][:id]),
  )

puts "Created VM"; pp destination
destination = RhevmVm.find_by_name(rhevm, destination_vm_name)
puts "Found VM"; pp destination
