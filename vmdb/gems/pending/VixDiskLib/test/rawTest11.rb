$:.push("#{File.dirname(__FILE__)}/..")
require 'rubygems'
require "VixDiskLib_raw"
require 'log4r'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

vmdk = "/vmfs/volumes/47dade33-4f4a4875-3951-00188b404015/rpo-test2/rpo-test2.vmdk"

VixDiskLib_raw.verbose = true

VixDiskLib_raw.init(lambda { |s| puts "INFO: #{s}" },
                    lambda { |s| puts "WARN: #{s}" },
                    lambda { |s| puts "ERROR: #{s}" }, nil)


tmodes = VixDiskLib_raw.listTransportModes
puts "Transport Modes = [#{tmodes}]"

conParms = {
    :serverName => "",
    :port       => 902,
    :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
    :userName   => "",
    :password   => "",
}

# connection = VixDiskLib_raw.connect(conParms)
connection = VixDiskLib_raw.connectEx(conParms, true, nil, nil)

dHandle = VixDiskLib_raw.open(connection, vmdk, VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_READ_ONLY)
dinfo = VixDiskLib_raw.getInfo(dHandle)
puts
puts "Disk info:"
dinfo.each { |k, v| puts "\t#{k} => #{v}" }
puts

mode = VixDiskLib_raw.getTransportMode(dHandle)
puts "Transport Mode: #{mode}"

mkeys = VixDiskLib_raw.getMetadataKeys(dHandle)
puts "Metadata:"
mkeys.each { |k| 
  v = VixDiskLib_raw.readMetadata(dHandle, k)
  puts "\t#{k} => #{v}" 
}

space = VixDiskLib_raw.spaceNeededForClone(dHandle, VixDiskLib_raw::VIXDISKLIB_DISK_VMFS_FLAT)
puts "Space Needed for Clone: #{space}"

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

# puts "Calling Cleanup"
# ncleaned, nremaining = VixDiskLib_raw.cleanup(conParms)
# puts "Cleanup << ncleaned=#{ncleaned}, nremaining=#{nremaining}"

VixDiskLib_raw.exit
