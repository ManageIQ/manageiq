$:.push("#{File.dirname(__FILE__)}/../../VMwareWebService")
$:.push("#{File.dirname(__FILE__)}/../../disk")
$:.push("#{File.dirname(__FILE__)}/..")

require 'rubygems'
require 'log4r'
require 'MiqVimClientBase'
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

begin
	vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    
	puts
    puts "vim.class: #{vim.class}"
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

	#
	# We can't do this if the VM is powered on.
	#
	if miqVm.poweredOn?
		puts "VM: #{TARGET_VM} is powered on"
		exit
	end
	
	#
	# Construct the path to the new payload vmdk file.
	#
	payloadVmdk = File.join(File.dirname(miqVm.dsPath),		"miqPayload.vmdk")
    puts "payloadVmdk = #{payloadVmdk}"

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
