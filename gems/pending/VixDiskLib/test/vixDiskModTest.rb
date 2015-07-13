$:.push("#{File.dirname(__FILE__)}/../../disk")
$:.push("#{File.dirname(__FILE__)}/../../fs/MiqFS")
$:.push("#{File.dirname(__FILE__)}/..")

require 'MiqDisk'
require 'MiqFS'
require 'VixDiskLib'
require 'ostruct'
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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

$log = $vim_log

VixDiskLib.init

conParms = {
    :serverName => "",
    :port       => 902,
    :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
    :userName   => "",
    :password   => "",
}

connection = VixDiskLib.connect(conParms)

diskFiles = [
    "/vmfs/volumes/StarM2-LUN1/VMmini-101/VMmini-101.vmdk"
]

vixDiskInfo = {
    :connection => connection,
    :fileName   => "/vmfs/volumes/StarM2-LUN1/VMmini-101/VMmini-101.vmdk"
}

dInfo = OpenStruct.new
dInfo.vixDiskInfo = vixDiskInfo

disks = Array.new

diskFiles.each do |df|
    puts "*** Disk file: #{df}"
    dInfo.vixDiskInfo[:fileName] = df
    
    disk = MiqDisk.getDisk(dInfo)
    if !disk
        puts "Failed to open disk"
        exit(1)
    end
    
    disks << disk

    puts "Disk type: #{disk.diskType}"
    puts "Disk partition type: #{disk.partType}"
    puts "Disk block size: #{disk.blockSize}"
    puts "Disk start LBA: #{disk.lbaStart}"
    puts "Disk end LBA: #{disk.lbaEnd}"
    puts "Disk start byte: #{disk.startByteAddr}"
    puts "Disk end byte: #{disk.endByteAddr}"

    parts = disk.getPartitions

    next if !parts

    foundFs = nil
    i = 1
    parts.each do |p|
        puts "\nPartition #{i}:"
        puts "\tDisk type: #{p.diskType}"
        puts "\tPart partition type: #{p.partType}"
        puts "\tPart block size: #{p.blockSize}"
        puts "\tPart start LBA: #{p.lbaStart}"
        puts "\tPart end LBA: #{p.lbaEnd}"
        puts "\tPart start byte: #{p.startByteAddr}"
        puts "\tPart end byte: #{p.endByteAddr}"
        puts
        fs = MiqFS.getFS(p)
        if fs
            foundFs = fs
            puts "\tFound File System: #{foundFs.fsType}"
        else
            puts "\tNo File System detected."
        end
        i += 1
        puts
    end

    if !foundFs
        puts "No File Systems found."
        exit(0)
    end

    puts "Mounted File System: #{foundFs.fsType}"
    puts "List of #{foundFs.pwd} directory:"
    foundFs.dirForeach { |de| puts "\t#{de}" }
    puts
end

disks.each(&:close)
connection.disconnect
