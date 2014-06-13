$:.push("#{File.dirname(__FILE__)}/../../VMwareWebService")
$:.push("#{File.dirname(__FILE__)}/../../disk")
$:.push("#{File.dirname(__FILE__)}/..")

require 'rubygems'
require 'log4r'
require 'VimClientBase'
require 'MiqVim'
require 'MiqVimBroker'
require 'MiqDisk'
require 'MiqPayloadOutputter'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$log.add 'err_console'

$stdout.sync = true
$stderr.sync = true

MKFILE	= "payload"
SERVER    = raise "please define SERVER"
USERNAME  = raise "please define USERNAME"
PASSWORD  = raise "please define PASSWORD"
TARGET_VM = raise "please define"
LOG_SIZE = 4096

MB = 1024 * 1024

vmMor = nil
miqVm = nil
vdlConnection = nil

begin
	vim = MiqVim.new(SERVER,USERNAME,PASSWORD)
    
	puts
    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts
    
	#
	# Get the target VM
	#
    tvm = vim.virtualMachinesByFilter("config.name" => TARGET_VM)
    if tvm.empty?
        puts "VM: #{TARGET_VM} not found"
        exit
    end
    vmMor = tvm[0]['MOR']
    miqVm = vim.getVimVmByMor(vmMor)

	######################################################
	# def update(payload, logSize=1048576, snapshot=true)
	######################################################

	#
	# We can't do this if the VM is powered on.
	#
	if miqVm.poweredOn?
		puts "VM: #{TARGET_VM} is powered on"
		exit
	end
	
	#
	# Snapshot the VM before we change it.
	#
	miqVm.createSnapshot("MiqAutomateSnapshot", "Pre-automate snapshot of VM - #{Time.now.utc.to_s}", "false", "false")
	
	#
	# Construct the path to the new payload vmdk file.
	#
	payloadVmdk = File.join(File.dirname(miqVm.dsPath), "miqPayload.vmdk")
    puts "payloadVmdk = #{payloadVmdk}"
	
	#
	# Calculate the size of the payload disk based of the size of the mkfs file.
	#
	mkSize = File.size(MKFILE)
	diskSzMb = (mkSize + LOG_SIZE + Log4r::MiqPayloadOutputter::HEADER_SIZE)/MB + 1
	
	#
	# Create the payload disk and attach it to the VM.
	#
	miqVm.addDisk(payloadVmdk, diskSzMb)
	
	#
	# Open a VixDiskLib connection.
	#
	vdlConnection = vim.vdlConnection
	
	#
	# Instantiate a MiqDisk object based on the vdl connection,
	# giving us remote write access to the new disk.
	#
	vixDiskInfo = { :connection => vdlConnection, :fileName   => payloadVmdk}
	dInfo = OpenStruct.new
	dInfo.mountMode = "rw"
	dInfo.vixDiskInfo = vixDiskInfo
	disk = MiqDisk.getDisk(dInfo)
    if !disk
        puts "Failed to open disk for writing"
        exit(1)
    end

	#
	# Calculate the offset on the disk at which the mkfs should start.
	#
	diskSize = disk.endByteAddr - disk.startByteAddr
	diskOffset = diskSize - mkSize

	puts
	puts "Disk size:   #{diskSize}"
	puts "Mk size:     #{mkSize}"
	puts "Disk offset: #{diskOffset}"
	puts

	#
	# Write the mkfs data to the disk.
	#
	mkf = File.open(MKFILE)
	print "Writing mkfs"
	disk.seek(diskOffset)
	while (buf = mkf.read(8192)) do
		print "."
		disk.write(buf, buf.length)
	end
	puts "done."
	mkf.close
	
	logHeader = Log4r::MiqPayloadOutputter.genHeader(LOG_SIZE)
	disk.seek(0)
	wb = disk.write(logHeader, logHeader.length)
	disk.close
	if wb != Log4r::MiqPayloadOutputter::HEADER_SIZE
		puts "Failed to write log header"
		exit 1
	end
	
	#
	# Attach the automate ISO CD image to the VM's CDROM drive.
	#
	miqVm.attachIsoToCd("[DEVOpen-E0] MIQ-FILES/miqknoppix.iso")
	
	#
	# Stert the VM, booting to the CD.
	#
	miqVm.start
	
	#
	# Wait for the VM to boot up and shut down.
	#
	while !miqVm.poweredOn?
		sleep 5
	end
	while !miqVm.poweredOff?
		sleep 5
	end
	
	#
	# Disconnect the automate ISO CD image from the VM's CDROM drive.
	#
	miqVm.resetCd
	
	#
	# Open the payload disk and retrieve the log.
	#
	dInfo.mountMode = "r"
	disk = MiqDisk.getDisk(dInfo)
    if !disk
        puts "Failed to open payload disk for reading"
        exit(1)
    end

	disk.seek(0)
	magic, size, pos = disk.read(Log4r::MiqPayloadOutputter::HEADER_SIZE).unpack("a8LL")
	
	puts
	puts "MAGIC: #{magic}"
	puts "SIZE: #{size}"
	puts "POS: #{pos}"
	puts
	
	puts
	puts "*** LOG START"
	puts disk.read(pos)
	puts "*** LOG END"
	
	disk.close
	
	#
	# Remove the payload disk from the VM.
	#
	miqVm.removeDiskByFile(payloadVmdk, true)
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    puts
    puts "Exiting..."
    miqVm.release if miqVm
	vdlConnection.disconnect if vdlConnection
    vim.disconnect if vim
end
