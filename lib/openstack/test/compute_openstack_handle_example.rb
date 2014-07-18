
$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../..")

EMS_IP       = ""
EMS_USERNAME = ""
EMS_PASSWORD = ""

require 'bundler_setup'
require 'openstack_handle'

def dump_attrs(obj, pref = "")
  unless obj.respond_to?(:attributes)
    puts "#{pref}#{obj.class.name} does not support attributes."
    return
  end

  puts "#{pref}#{obj.class.name} attributes:"
  obj.attributes.each do |k, v|
    puts "#{pref}\t#{k}:\t#{v}"
  end
  puts
end

begin
  os_handle = OpenstackHandle::Handle.new(EMS_USERNAME, EMS_PASSWORD, EMS_IP)

  puts "**** Tenants:"
  os_handle.tenants.each do |t|
    puts "\t#{t.name}\t(#{t.id})"
  end

  compute_service = os_handle.compute_service

  servers = compute_service.servers.all(:detailed => true, :all_tenants => true)
  puts
  puts servers.class.name

  puts "**** servers (#{servers.length}):"
  servers.each do |s|
    # puts "\t#{s.name}\t(#{s.id})"
    dump_attrs(s, "\t")
  end

  hosts = compute_service.hosts.all
  puts
  puts hosts.class.name

  puts "**** hosts (#{hosts.length}):"
  hosts.each do |h|
    # puts "\t#{h.name}\t(#{h.id})"
    dump_attrs(h, "\t")
  end
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
end
