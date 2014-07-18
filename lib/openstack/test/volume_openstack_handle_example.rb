
$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../..")

EMS_IP       = ""
EMS_USERNAME = ""
EMS_PASSWORD = ""

require 'bundler_setup'
require 'openstack_handle'

begin
  os_handle = OpenstackHandle::Handle.new(EMS_USERNAME, EMS_PASSWORD, EMS_IP)

  puts "**** Tenants:"
  os_handle.tenants.each do |t|
    puts "\t#{t.name}\t(#{t.id})"
  end

  unless os_handle.volume_service_name == :cinder
    puts "Volume service cinder is not available, exiting."
    exit
  end

  puts
  puts "**** Volumes/Snapshots by tenant:"

  os_handle.tenant_names.each do |tn|
    next if tn == "services"

    puts
    puts "\tVolumes for tenant: #{tn}"
    fog_volume = os_handle.volume_service(tn)
    fog_volume.volumes.each do |v|
      puts
      puts "\t\t#{v.display_name}: #{v.id}"
      v.attributes.each do |ak, av|
        puts "\t\t\t#{ak}:\t#{av}"
      end
    end

    puts
    puts "\tSnapshots for tenant: #{tn}"

    snaps = fog_volume.list_snapshots.body['snapshots']
    snaps.each do |snap|
      puts
      puts "\t\t#{snap['display_name']}: #{snap['id']}"
      snap.each do |k, v|
        puts "\t\t\t#{k}:\t#{v}"
      end
      puts
    end
  end
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
end
