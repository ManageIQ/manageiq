$:.push("#{File.dirname(__FILE__)}/..")

require "VixDiskLib"
require 'enumerator'
require 'rubygems'
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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

diskFiles = [
      "/vmfs/volumes/StarM2-LUN1/VMmini-101/VMmini-101.vmdk"
]

readRanges = [
       0,  256,
       0,  512,
     256,  512,
     512,  256,
     512,  512,
     256, 1024,
    1280,  256,
    1280,  512,
    1280, 1024
]

puts "VIXDISKLIB_FLAG_OPEN_UNBUFFERED  = #{VixDiskLib::VIXDISKLIB_FLAG_OPEN_UNBUFFERED}"
puts "VIXDISKLIB_FLAG_OPEN_SINGLE_LINK = #{VixDiskLib::VIXDISKLIB_FLAG_OPEN_SINGLE_LINK}"
puts "VIXDISKLIB_FLAG_OPEN_READ_ONLY   = #{VixDiskLib::VIXDISKLIB_FLAG_OPEN_READ_ONLY}"
puts "VIXDISKLIB_CRED_UID              = #{VixDiskLib::VIXDISKLIB_CRED_UID}"
puts "VIXDISKLIB_CRED_SESSIONID        = #{VixDiskLib::VIXDISKLIB_CRED_SESSIONID}"
puts "VIXDISKLIB_CRED_UNKNOWN          = #{VixDiskLib::VIXDISKLIB_CRED_UNKNOWN}"
puts "VIXDISKLIB_SECTOR_SIZE           = #{VixDiskLib::VIXDISKLIB_SECTOR_SIZE}"
puts

VixDiskLib.init(lambda { |s| puts "INFO: #{s}" },
                lambda { |s| puts "WARN: #{s}" },
                lambda { |s| puts "ERROR: #{s}" })
                    
conParms = {
    :serverName => "",
    :port       => 902,
    :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
    :userName   => "",
    :password   => "",
}

connection = VixDiskLib.connect(conParms)

vDisks = Array.new

n = 1
diskFiles.each do |vmdk|
    puts "*** #{n} *** VMDK: #{vmdk}"                  
    vDisk = connection.getDisk(vmdk, VixDiskLib::VIXDISKLIB_FLAG_OPEN_READ_ONLY)
    vDisks << vDisk

    dinfo = vDisk.info
    puts
    puts "Disk info:"
    dinfo.each { |k, v| puts "\t#{k} => #{v}"}
    puts

    readRanges.each_slice(2) do |start, len|
        puts "Read test: start = #{start}, len = #{len} (bytes)"
        startSector, startOffset = start.divmod(vDisk.sectorSize)
        endSector = (start+len-1)/vDisk.sectorSize
        numSector = endSector - startSector + 1
        puts "\tstartSector = #{startSector}, numSector = #{numSector}, startOffset = #{startOffset}"
    
        rBData = vDisk.bread(startSector, numSector)
        puts "\tBlock read #{rBData.length} bytes of data."
    
        rCData = vDisk.read(start, len)
        puts "\tByte read #{rCData.length} bytes of data."
    
        if rCData != rBData[startOffset, len]
            puts "\t\t*** Block and byte data don't match"
        else
            puts "\t\tData check passed"
        end
        puts
    end
    n += 1
    
    break
end

vDisks.each { |vDisk| vDisk.close }
connection.disconnect
