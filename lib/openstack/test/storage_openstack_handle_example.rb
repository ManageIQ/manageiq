
$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../..")

EMS_IP       = ""
EMS_USERNAME = ""
EMS_PASSWORD = ""

require 'bundler_setup'
require 'excon'
require 'openstack_handle'

begin
  os_handle = OpenstackHandle::Handle.new(EMS_USERNAME, EMS_PASSWORD, EMS_IP)
  os_handle.connection_options = {:instrumentor => Excon::StandardInstrumentor}

  puts "**** Tenants:"
  os_handle.tenants.each do |t|
    puts "\t#{t.name}\t(#{t.id})"
  end

  unless os_handle.storage_service_name == :swift
    puts "Storeage service swift is not available, exiting."
    exit
  end

  puts
  puts "**** Object storage by tenant:"

  os_handle.tenant_names.each do |tn|
    next if tn == "services"

    puts
    puts "\tDirectories for tenant: #{tn}"
    fog_storage = os_handle.storage_service(tn)
    fog_storage.directories.each do |d|
      puts
      puts "\t\t#{d.class.name}"
      d.attributes.each do |ak, av|
        puts "\t\t\t#{ak}:\t#{av}"
      end
      puts
      d.files.each do |f|
        puts "\t\t\t#{f.class.name}"
        f.attributes.each do |fak, fav|
          puts "\t\t\t\t#{fak}:\t#{fav}"
        end
      end
    end
  end
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
end
