$:.push("#{File.dirname(__FILE__)}/..")

require "ezcrypto"
require "VixDiskLib_raw"

vmdk =  "/vmfs/volumes/StarM2-LUN1/VMmini-101/VMmini-101.vmdk"

conParms = {
    :serverName => "",
    :port       => 902,
    :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
    :userName   => "",
    :password   => "",
}

def getKey
  EzCrypto::Key.with_password "55555", "999999999", :algorithm => "aes-256-cbc"
end

puts "***** cs1"
cs1 = getKey
puts cs1Str = cs1.encrypt("Hello cs1")
puts cs1.decrypt(cs1Str)
puts "***** cs1 OK"

VixDiskLib_raw.init(lambda { |s| puts "INFO: #{s}" },
                    lambda { |s| puts "WARN: #{s}" },
                    lambda { |s| puts "ERROR: #{s}" }, nil)

puts "***** cs2"
cs2 = getKey
puts cs2.decrypt(cs2.encrypt("Hello cs2"))
puts "***** cs2 OK"

connection = VixDiskLib_raw.connect(conParms)

puts "***** cs3"
cs3 = getKey
puts cs3.decrypt(cs3.encrypt("Hello cs3"))
puts "***** cs3 OK"

dHandle = VixDiskLib_raw.open(connection, vmdk, VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_READ_ONLY)

puts "***** cs4"
cs4 = getKey
puts cs4.decrypt(cs4.encrypt("Hello cs4"))
puts "***** cs4 OK"

puts "***** cs5"
cs5 = getKey
puts cs5.decrypt(cs1Str)
puts "***** cs5 OK"

dinfo = VixDiskLib_raw.getInfo(dHandle)
puts
puts "Disk info:"
dinfo.each { |k, v| puts "\t#{k} => #{v}" }
puts

# nReads = 500000
nReads = 500

bytesRead = 0
t0 = Time.now

(0...nReads).each do |rn|
    rData = VixDiskLib_raw.read(dHandle, rn, 1)
    bytesRead += rData.length
end

t1 = Time.now
bps = bytesRead/(t1-t0)

puts "Read throughput: #{bps} B/s"

VixDiskLib_raw.close(dHandle)

VixDiskLib_raw.disconnect(connection)
VixDiskLib_raw.exit
