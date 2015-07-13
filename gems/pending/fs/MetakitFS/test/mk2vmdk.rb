$:.push("#{File.dirname(__FILE__)}/../../../disk")

require 'rubygems'
require 'log4r'
require 'ostruct'
require 'MiqDisk'

VMDK	= "/Volumes/WDpassport/Virtual Machines/Red Hat Linux.vmwarevm/payload2.vmdk"
MKFILE	= "rawmkfs"

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$log = Log4r::Logger.new 'toplog'
$log.level = Log4r::DEBUG
Log4r::StderrOutputter.new('err_console', :formatter=>ConsoleFormatter)
$log.add 'err_console'

diskInfo = OpenStruct.new
diskInfo.mountMode = "rw"
diskInfo.fileName = VMDK

disk = MiqDisk.getDisk(diskInfo)

if !disk
    puts "Failed to open disk: #{diskInfo.fileName}"
    exit(1)
end

puts "Disk type: #{disk.diskType}"
puts "Disk partition type: #{disk.partType}"
puts "Disk block size: #{disk.blockSize}"
puts "Disk start LBA: #{disk.lbaStart}"
puts "Disk end LBA: #{disk.lbaEnd}"
puts "Disk start byte: #{disk.startByteAddr}"
puts "Disk end byte: #{disk.endByteAddr}"
puts

parts = disk.getPartitions

if parts && !parts.empty?
	puts "Disk is partitioned, exiting"
	exit(0)
end

diskSize = disk.endByteAddr - disk.startByteAddr
mkSize = File.size(MKFILE)
diskOffset = diskSize - mkSize

puts "Disk size:   #{diskSize}"
puts "Mk size:     #{mkSize}"
puts "Disk offset: #{diskOffset}"

mkf = File.open(MKFILE)

disk.seek(diskOffset)
while (buf = mkf.read(1024)) do
	disk.write(buf, buf.length)
end

mkf.close
disk.close
