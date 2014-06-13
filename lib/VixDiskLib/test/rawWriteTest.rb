$:.push("#{File.dirname(__FILE__)}/..")

require "VixDiskLib_raw"

vmdk = "/vmfs/volumes/47dade33-4f4a4875-3951-00188b404015/rpo-test2/rpo-test2_1.vmdk"

VixDiskLib_raw.init(nil)
connection = VixDiskLib_raw.connect(:serverName => "",
                                    :port       => 902,
                                    :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
                                    :userName   => "",
                                    :password   => "")

# dHandle = VixDiskLib_raw.open(connection, vmdk, VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_READ_ONLY)
dHandle = VixDiskLib_raw.open(connection, vmdk, 0)

wData = "5" * VixDiskLib_raw::VIXDISKLIB_SECTOR_SIZE

puts "Writing #{wData.length} bytes of data."
VixDiskLib_raw.write(dHandle, 0, 1, wData)
rData = VixDiskLib_raw.read(dHandle, 0, 1)
puts "Read #{rData.length} bytes of data."

if rData == wData
    puts "\tData check OK"
else
    puts "\tRead data does not match data written"
end

VixDiskLib_raw.close(dHandle)

VixDiskLib_raw.disconnect(connection)
VixDiskLib_raw.exit
