$: << File.dirname(__FILE__)

begin
	require 'rubygems'
	require 'log4r'
	require 'ostruct'
	require 'MiqDisk'

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
	diskInfo.rawDisk = true
	# diskInfo.fileName = File.join(File. dirname(__FILE__), "dos_mbr.img")
	# diskInfo.fileName = "/Users/rpo/vmware/Win2K3-EE/Windows Server 2003 Enterprise Edition-flat.vmdk"
	# diskInfo.fileName = "/Users/rpo/vmware/knoppixDVM/knoppixDVM.vmdk"
	# diskInfo.fileName = "/volumes/SCRATCH/VMs/VirtualPC/VHDFixedFAT32TwoPart/VHDFixedFAT32.vhd"

	diskInfo.fileName = "/dev/xvdf"
	# diskInfo.fileName = "./Win2k3R2EE.vhd"
	# diskInfo.fileName = "./Windows XP Pro 2.vhd"

	disk = MiqDisk.getDisk(diskInfo)

	if !disk
	    puts "Failed to open disk"
	    exit(1)
	end

	puts "Disk type: #{disk.diskType}"
	puts "Disk partition type: #{disk.partType}"
	puts "Disk block size: #{disk.blockSize}"
	puts "Disk start LBA: #{disk.lbaStart}"
	puts "Disk end LBA: #{disk.lbaEnd}"
	puts "Disk start byte: #{disk.startByteAddr}"
	puts "Disk end byte: #{disk.endByteAddr}"

	parts = disk.getPartitions

	exit(0) if !parts

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
	    i += 1
	end

	disk.close
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
