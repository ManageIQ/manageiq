$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../../VixDiskLib")

require_relative '../../bundler_setup'
require 'log4r'
require 'enumerator'

require 'MiqVimBroker'
# require 'MiqVim'
require 'VixDiskLib'

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

$stderr.sync = true
$stdout.sync = true

# $DEBUG = true
# MiqVimClientBase.wiredump_file = "clone.txt"

SRC_VM      = "rpo-test2"

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

vDisk	= nil
vdlc	= nil

begin
    broker = MiqVimBroker.new(:client)
	if !broker.serverAlive?
		puts "Broker server isn't running"
		exit
	end

	t0 = Time.now

    vim = broker.getMiqVim.new(SERVER, USERNAME, PASSWORD)
    
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts

	svm = vim.virtualMachinesByFilter("config.name" => SRC_VM)
    if svm.empty?
        puts "VM: #{SRC_VM} not found"
        exit
    end

	puts "#{SRC_VM} vmPathName:      #{svm[0]['summary']['config']['vmPathName']}"
	puts "#{SRC_VM} vmLocalPathName: #{svm[0]['summary']['config']['vmLocalPathName']}"

    sVmMor = svm[0]['MOR']
    miqVm = vim.getVimVmByMor(sVmMor)
    
    puts "VM: #{miqVm.name}, HOST: #{miqVm.hostSystem}"
    puts

	diskFile = miqVm.getCfg['scsi0:0.filename']
	ldiskFile = vim.localVmPath(diskFile)
	puts "diskFile: #{diskFile}"
	puts "ldiskFile: #{ldiskFile}"
	puts

	if vim.isVirtualCenter?
		puts "Calling: miqVm.vdlVcConnection"
		vdlc = miqVm.vdlVcConnection
		vDisk = vdlc.getDisk(diskFile, VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_READ_ONLY)
	else
		vdlc = vim.vdlConnection
		vDisk = vdlc.getDisk(ldiskFile, VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_READ_ONLY)
	end
	
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

rescue => err
    puts err
	puts err.class.to_s
    puts err.backtrace.join("\n")
ensure
	vDisk.close if vDisk
	vdlc.disconnect if vdlc
end
