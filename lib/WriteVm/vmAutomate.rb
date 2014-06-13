$:.push(File.dirname(__FILE__))
$:.push("#{File.dirname(__FILE__)}/../fs")

require 'rubygems'
require 'log4r'

require 'MiqNativeMountManager'
require 'MiqFsUtil'
require 'MiqPayloadOutputter'

PAYLOAD_SPEC = "/miq_payload.yaml"

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
	@@prog = File.basename(__FILE__, ".*")
	def format(event)
		"#{Log4r::LNAMES[event.level]} [#{datetime}] -- #{@@prog}: " +
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
	
	private
	
	def datetime
		time = Time.now.utc
		time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d " % time.usec
	end
	
end
$log = Log4r::Logger.new 'toplog'
$log.level = Log4r::DEBUG
po = Log4r::MiqPayloadOutputter.new('err_console', :formatter=>ConsoleFormatter)
$log.add 'err_console'

rootTrees = nil

begin
	$log.info "MIQ VM UPDATE START"
	rootTrees = MiqNativeMountManager.mountVolumes

	if rootTrees.nil? || rootTrees.empty?
		$log.info "No root filesystems detected"
		exit
	end

	rootTree = rootTrees[0]

	rootTree.payloads.each do |p|
		$log.info "*** Processing Payload: #{p.dobj.devFile}"
		if !p.fileExists?(PAYLOAD_SPEC)
			$log.info "\tPayload spec not found. Skipping #{p.dobj.devFile}"
			next
		end
		fsu = MiqFsUtil.new(p, rootTree)
		fsu.verbose = true
		fsu.loadUpdateSpec(PAYLOAD_SPEC)
		fsu.update
	end
	$log.info "MIQ VM UPDATE SUCCEEDED"
rescue => err
	$log.error err.to_s
	$log.error err.backtrace.join("\n")
	$log.error "MIQ VM UPDATE FAILED"
ensure
	rootTrees.each do |r|
		r.umount
	end if rootTrees
	$log.info "MIQ VM UPDATE END - " + (lo.partialLog ? "partial log" : "full log")
end
