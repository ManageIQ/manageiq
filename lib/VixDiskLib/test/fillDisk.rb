$:.push("#{File.dirname(__FILE__)}/..")

require "VixDiskLib_raw"

vmdk = "/vmfs/volumes/47dade33-4f4a4875-3951-00188b404015/rpo-test2/rpo-test2_1.vmdk"

VixDiskLib_raw.init(nil)
conParms = {
    :serverName => "",
    :port       => 902,
    :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
    :userName   => "",
    :password   => "",
}

connection = VixDiskLib_raw.connect(conParms)
dHandle = VixDiskLib_raw.open(connection, vmdk, 0)
dinfo = VixDiskLib_raw.getInfo(dHandle)

wData = "5" * VixDiskLib_raw::VIXDISKLIB_SECTOR_SIZE

(0...dinfo[:capacity]).each do |s|
    puts "Writing sector: #{s}"
    VixDiskLib_raw.write(dHandle, s, 1, wData)
end

VixDiskLib_raw.close(dHandle)

VixDiskLib_raw.disconnect(connection)
VixDiskLib_raw.exit
