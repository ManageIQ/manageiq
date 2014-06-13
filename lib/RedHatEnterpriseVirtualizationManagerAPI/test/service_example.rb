# Push the lib directory onto the load path
$:.push(File.expand_path(File.join(File.dirname(__FILE__), '..', '..')))

require_relative '../../bundler_setup'
require_relative '../rhevm_api'

RHEVM_SERVER        = raise "please define RHEVM_SERVER"
RHEVM_PORT_3_1      = 443
RHEVM_DOMAIN        = raise "please define RHEVM_DOMAIN"
RHEVM_USERNAME      = raise "please define RHEVM_USERNAME"
RHEVM_PASSWORD      = raise "please define RHEVM_PASSWORD"

rhevm = RhevmService.new(
          :server   => RHEVM_SERVER,
          :port     => RHEVM_PORT_3_1,
          :domain   => RHEVM_DOMAIN,
          :username => RHEVM_USERNAME,
          :password => RHEVM_PASSWORD)

require 'pp'

# pp rhevm.api

puts "NAME: #{rhevm.name}"
puts "VENDOR: #{rhevm.vendor}"
puts "VERSION: #{rhevm.version_string}"

pp rhevm.blank_template
pp rhevm.root_tag
pp rhevm.summary

puts "API:#{rhevm.api.inspect}"
puts "Capabilities:\t#{rhevm.resource_get(:capabilities)}"
#puts "Users:\t#{rhevm.resource_get(:users)}"
#puts "Groups:\t#{rhevm.resource_get(:groups)}"
puts "Roles:\t#{rhevm.resource_get(:roles)}"
puts "Tags:\t#{rhevm.resource_get(:tags)}"
puts "Datacenters:\t#{rhevm.resource_get(:datacenters)}"
puts "Storage Domains:\t#{rhevm.resource_get(:storagedomains)}"
puts "Networks:\t#{rhevm.resource_get(:networks)}"
puts "Clusters:\t#{rhevm.resource_get(:clusters)}"
puts "Hosts:\t#{rhevm.resource_get(:hosts)}"
puts "VMPools:\t#{rhevm.resource_get(:vmpools)}"
puts "VMs:\t#{rhevm.resource_get(:vms)}"
puts "Templates:\t#{rhevm.resource_get(:templates)}"
puts "Events:\t#{rhevm.resource_get(:events)}"
