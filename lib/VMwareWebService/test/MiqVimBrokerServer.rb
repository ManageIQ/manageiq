
$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'log4r'
require 'MiqVimBroker'

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

#
# Formatter to output log messages to the console.
#
$stderr.sync = true
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		t = Time.now
		"[%s] %02d:%02d:%02d <%s>: %s\n" % [Log4r::LNAMES[event.level], t.hour, t.min, t.sec, Thread.current.object_id, event.data.kind_of?(String) ? event.data : event.data.inspect]
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

broker = nil

trap(:INT) do
	puts "Connection broker ignoring INT."
end

MiqVimBroker.preLoad        = true
MiqVimBroker.debugUpdates   = false
# MiqVimBroker.updateDelay	= 120

# MiqVimBroker.setSelector(SelectionSpec)

nmSync = Sync.new

# MiqVimBroker.notifyMethod = lambda { |h|
# 	nmSync.synchronize(:EX) do
# 		puts
# 		puts "***"
# 		h.each do |k,v|
# 			if k == :changedProps
# 				puts "#{k} =>"
# 				v.each { |pn| puts "\t#{pn}" }
# 				next
# 			end
# 			puts "#{k} => #{v}"
# 		end
# 	end
# }

$miq_wiredump = false
$sim_update_reply = false

broker = MiqVimBroker.new(:server)
broker.cacheScope = :cache_scope_core
# broker = MiqVimBroker.new(:server, 0)
puts "Broker server started at #{DRb.uri}"

# sleep 300
# puts "setting upate delay to 30"
# broker.updateDelay = 30
# broker.debugUpdates = true
# broker.notifyMethod = nil

DRb.thread.join
