EMS_IP.freeze       = ""
EMS_USERNAME.freeze = ""
EMS_PASSWORD.freeze = ""

# Following lines with require seem to be broken, copy code to rails console...
# require_relative '../../bundler_setup'
require 'openstack/openstack_handle'
# require 'openstack/events/openstack_ceilometer_event_monitor'

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
  os_handle = OpenstackHandle::Handle.new(EMS_USERNAME, EMS_PASSWORD, EMS_IP, nil, nil, 'non-ssl')

  metering_service = os_handle.metering_service

  puts "**** resources"
  p metering_service.resources

  puts "**** events"
  p metering_service.events

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
end
