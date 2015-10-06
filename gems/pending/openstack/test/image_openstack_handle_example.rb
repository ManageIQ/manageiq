EMS_IP       = ""
EMS_USERNAME = ""
EMS_PASSWORD = ""

require_relative '../../bundler_setup'
require 'openstack/openstack_handle'

begin
  os_handle = OpenstackHandle::Handle.new(EMS_USERNAME, EMS_PASSWORD, EMS_IP)

  puts "**** Tenants:"
  os_handle.tenants.each do |t|
    puts "\t#{t.name}\t(#{t.id})"
  end

  unless os_handle.image_service.name == :glance
    puts "Image service glance is not available, exiting."
    exit
  end

  fog_image = os_handle.image_service
  images = fog_image.images.all

  puts
  puts "**** All images (#{images.length}):"
  images.each do |i|
    puts
    puts "\t\t#{i.name}: #{i.id}"
    i.attributes.each do |ak, av|
      puts "\t\t\t#{ak}:\t#{av}"
    end
  end
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
end
