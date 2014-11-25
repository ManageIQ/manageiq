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
		"config.consoleReservation.serviceConsoleReserved",
		"config.network.consoleVnic[*].device",
		"config.network.consoleVnic[*].port",
		"config.network.consoleVnic[*].portgroup",
		"config.network.consoleVnic[*].spec.ip.dhcp",
		"config.network.consoleVnic[*].spec.ip.ipAddress",
		"config.network.consoleVnic[*].spec.ip.subnetMask",
		"config.network.dnsConfig.domainName",
		"config.network.dnsConfig.hostName",
		"config.network.pnic[*].device",
		"config.network.pnic[*].key",
		"config.network.pnic[*].pci",
		"config.network.portgroup[*].port[*].key",
		"config.network.portgroup[*].spec.name",
		"config.network.portgroup[*].spec.vlanId",
		"config.network.portgroup[*].spec.vswitchName",
		"config.network.portgroup[*].vswitch",
		"config.network.vswitch[*].key",
		"config.network.vswitch[*].name",
		"config.network.vswitch[*].numPorts",
		"config.network.vswitch[*].pnic",
		"config.service.service[*].key",
		"config.service.service[*].label",
		"config.service.service[*].running",
		"datastore",
		# "datastore.ManagedObjectReference",
		"name",
		"summary.config.name",
		"summary.config.product.build",
		"summary.config.product.name",
		"summary.config.product.osType",
		"summary.config.product.vendor",
		"summary.config.product.version",
		"summary.config.vmotionEnabled",
		"summary.hardware.cpuMhz",
		"summary.hardware.cpuModel",
		"summary.hardware.memorySize",
		"summary.hardware.model",
		"summary.hardware.numCpuCores",
		"summary.hardware.numCpuPkgs",
		"summary.hardware.numNics",
		"summary.hardware.vendor",
		"summary.quickStats.overallCpuUsage",
		"summary.quickStats.overallMemoryUsage",
		"summary.runtime.connectionState",
		"summary.runtime.inMaintenanceMode"
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
hMor = nil

MiqVim.setSelector(SelectionSpec)

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
miqHost = nil

begin
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

	puts "**** Selector specs by value"
	puts
	
	#
	# Now, set the  SelectionSpec in the server, and reference them by name.
	#
	puts
	puts "**** Selector specs by name (reference)"
	puts
	
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
	
	#
	# Remove SelectionSpec from the server, and check for expected failure.
	#
	puts
	puts "**** Remove Selector specs..."
	
	vim.removeSelector(SelectionSpec)
	
	begin
		puts
		puts "*** storageDevice START"
		sd = miqHost.storageDevice(:storageDeviceSS)
		vim.dumpObj(sd)
		puts "*** storageDevice END"
	rescue => err
		puts "*** storageDevice expected error: #{err}"
	end
	
	#
	# Re-add SelectionSpec and try again.
	#
	puts
	puts "**** Set Selector specs..."
	
	vim.setSelector(SelectionSpec)
	
	begin
		puts
		puts "*** storageDevice START"
		sd = miqHost.storageDevice(:storageDeviceSS)
		vim.dumpObj(sd)
		puts "*** storageDevice END"
	rescue => err
		puts "*** storageDevice unexpected error: #{err}"
	end
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqHost.release if miqHost
    vim.disconnect
end
