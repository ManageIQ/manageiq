# Push the lib directory onto the load path
$:.push(File.expand_path(File.join(File.dirname(__FILE__), '..', '..')))

require_relative '../../bundler_setup'
require_relative '../rhevm_api'
require 'pp'

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

pp rhevm.iso_storage_domain
pp rhevm.iso_images
