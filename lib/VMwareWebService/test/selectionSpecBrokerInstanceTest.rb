$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'log4r'
require 'MiqVim'
require 'MiqVimBroker'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::OFF, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

# $miq_wiredump = true

VimTestMethods = [
	:virtualMachines,
	:virtualMachinesByMor,
	:virtualMachineByMor,
	:computeResources,
	:computeResourcesByMor,
	:computeResourceByMor,
	:clusterComputeResources,
	:clusterComputeResourcesByMor,
	:clusterComputeResourceByMor,
	:resourcePools,
	:resourcePoolsByMor,
	:resourcePoolByMor,
	:folders,
	:foldersByMor,
	:folderByMor,
	:datacenters,
	:datacentersByMor,
	:datacenterByMor,
	:hostSystems,
	:hostSystemsByMor,
	:hostSystemByMor,
	:dataStores,
	:dataStoresByMor,
	:dataStoreByMor
]

SelectionSpec = {
	:virtualMachines => [
		"MOR",
		"config.name",
		"guest.net[*].ipAddress",
		"guest.net[*].macAddress"
	],
	
	:computeResources => [
		"MOR"
	],
	
	:clusterComputeResources => [
		"MOR",
		"name",
		"host",
		"configuration.drsConfig.defaultVmBehavior",
		"configuration.drsConfig.enabled"
	],
	
	:resourcePools => [
		"MOR",
		"name",
		"summary.configuredMemoryMB"
	],
	
	:folders => [
		"MOR",
		"name",
		"overallStatus"
	],
	
	:datacenters => [
		"MOR",
		"name",
		"overallStatus",
		"network"
	],
	
	:hostSystems => [
		"MOR",
		"summary.config.name",
		"hardware.systemInfo"
	],
	
	:dataStores => [
		"MOR",
		"info.name",
		"info.freeSpace"
	],

	:storageDeviceSS => [
		"config.storageDevice.hostBusAdapter[*].device",
		"config.storageDevice.hostBusAdapter[*].iScsiAlias",
		"config.storageDevice.hostBusAdapter[*].iScsiName",
		"config.storageDevice.hostBusAdapter[*].key",
		"config.storageDevice.hostBusAdapter[*].model",
		"config.storageDevice.hostBusAdapter[*].pci",
		"config.storageDevice.scsiLun[*].canonicalName",
		"config.storageDevice.scsiLun[*].capacity.block",
		"config.storageDevice.scsiLun[*].capacity.blockSize",
		"config.storageDevice.scsiLun[*].deviceName",
		"config.storageDevice.scsiLun[*].deviceType",
		"config.storageDevice.scsiLun[*].key",
		"config.storageDevice.scsiLun[*].lunType",
		"config.storageDevice.scsiLun[*].uuid",
		"config.storageDevice.scsiTopology.adapter[*].adapter",
		"config.storageDevice.scsiTopology.adapter[*].target[*].lun[*].lun",
		"config.storageDevice.scsiTopology.adapter[*].target[*].lun[*].scsiLun",
		"config.storageDevice.scsiTopology.adapter[*].target[*].target",
		"config.storageDevice.scsiTopology.adapter[*].target[*].transport.address",
		"config.storageDevice.scsiTopology.adapter[*].target[*].transport.iScsiAlias",
		"config.storageDevice.scsiTopology.adapter[*].target[*].transport.iScsiName"
	]
}

TARGET_HOST = raise "please define"
broker = MiqVimBroker.new(:client)
#
# Set SelectionSpec for all of the broker's connections.
#
broker.setSelector(SelectionSpec)

vim = broker.getMiqVim(SERVER, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
	
	VimTestMethods.each_slice(3) do |objs, objsbymor, objbymor|
		rv = vim.send(objsbymor, objs)
		next if rv.values.empty?
		mor = rv.values.first['MOR']
		
		puts
		puts "*** #{objsbymor} START"
		vim.dumpObj(rv)
		puts "*** #{objsbymor} END"
		
		rv = vim.send(objbymor, mor, objs)
		
		puts
		puts "*** #{objbymor} START"
		vim.dumpObj(rv)
		puts "*** #{objbymor} END"
		
		rv = vim.send(objs, objs)
	end

    miqHost = vim.getVimHost(TARGET_HOST)

	puts
	puts "*** storageDevice START"
	sd = miqHost.storageDevice(:storageDeviceSS)
	vim.dumpObj(sd)
	puts "*** storageDevice END"
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqHost.release if miqHost
    vim.disconnect
end
