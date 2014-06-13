require_relative "../../bundler_setup"
require_relative "../openstack_event_monitor"

def event_to_hash event
  hash = {}
  # copy content
  content = event.content
  hash[:content] = content.reject{|k,v| k.start_with? "_context_"}

  # copy context
  hash[:context] = {}
  content.select{|k,v| k.start_with? "_context_"}.each_pair do |k,v|
    hash[:context][k] = v
  end

  # copy attributes
  hash[:properties]     = event.properties
  hash[:user_id]        = event.user_id
  hash[:correlation_id] = event.correlation_id
  hash[:priority]       = event.priority
  hash[:content_type]   = event.content_type
  hash[:subject]        = event.subject
  hash[:reply_to]       = event.reply_to
  hash[:content_size]   = event.content_size
  hash
end

require 'pp'

OPENSTACK_RDU_DEV_SERVER = raise "please define"
OPENSTACK_RDU_DEV_PORT   = ""
OPENSTACK_RDU_USERNAME   = ""
OPENSTACK_RDU_PASSWORD   = ""

os_monitor = OpenstackEventMonitor.new(:hostname => OPENSTACK_RDU_DEV_SERVER,
                                       :username => OPENSTACK_RDU_USERNAME,
                                       :password => OPENSTACK_RDU_PASSWORD,
                                       :topics => {"nova"    => "notifications.*",
                                                   "glance"  => "notifications.*",
                                                   "cinder"  => "notifications.*",
                                                   "quantum" => "notifications.*"})

Signal.trap("INT") { os_monitor.stop }

os_monitor.start
puts "Connected ... waiting for Openstack events"
os_monitor.each do |event|
  puts "\n\nsaw event: #{event.content["event_type"]}"
  #pp event_to_hash event
end
