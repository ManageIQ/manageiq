$:.push("#{File.dirname(__FILE__)}/..")

require "VixDiskLib_raw"

from_vmdk = "/vmfs/volumes/47dade33-4f4a4875-3951-00188b404015/rpo-test2/rpo-test2-000001.vmdk"
to_vmdk = "/vmfs/volumes/47dade33-4f4a4875-3951-00188b404015/rpo-test2/rpo-test2_1_copy.vmdk"
temp_vmdk = File.join(File.dirname(__FILE__), "fii.vmdk")

conParms = {
    :serverName => "",
    :port       => 902,
    :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
    :userName   => "",
    :password   => "",
}

VixDiskLib_raw.init(lambda { |s| puts "INFO: #{s}" },
                    lambda { |s| puts "WARN: #{s}" },
                    lambda { |s| puts "ERROR: #{s}" }, nil)

rconnection = VixDiskLib_raw.connect(conParms)  # remote server
lconnection = VixDiskLib_raw.connect({})        # local

dHandle = VixDiskLib_raw.open(rconnection, from_vmdk, VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_READ_ONLY)

dinfo = VixDiskLib_raw.getInfo(dHandle)
puts
puts "Disk info:"
dinfo.each { |k, v| puts "\t#{k} => #{v}"}
puts

VixDiskLib_raw.close(dHandle)

createParms = {
    :diskType    => VixDiskLib_raw::VIXDISKLIB_DISK_MONOLITHIC_SPARSE,
    :adapterType => dinfo[:adapterType],
    :capacity    => dinfo[:capacity]
}

t0 = Time.now
VixDiskLib_raw.dclone(lconnection, temp_vmdk, rconnection, from_vmdk, createParms, true)
VixDiskLib_raw.dclone(rconnection, to_vmdk, lconnection, temp_vmdk, createParms, false)
t1 = Time.now

VixDiskLib_raw.disconnect(rconnection)
VixDiskLib_raw.disconnect(lconnection)
VixDiskLib_raw.exit

puts "Clone ET: #{t1-t0}"
