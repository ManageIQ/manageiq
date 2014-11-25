$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'RcuClientBase'

#
# Create 2 clones on newly created NFS datastore.
#

VC				= raise "please define"
VC_USER			= raise "please define"
VC_PASSWORD		= raise "please define"

FILER			= raise "please define"
FILER_USER		= raise "please define"
FILER_PASSWORD	= raise "please define"

TARGET_HOST		= raise "please define"
SOURCE_VM		= raise "please define"

begin
	
	rcu = RcuClientBase.new(VC, VC_USER, VC_PASSWORD)
	
	controller = RcuHash.new("ControllerSpec") do |cs|
		cs.ipAddress	= FILER
		cs.password		= FILER_PASSWORD
		cs.ssl			= false
		cs.username		= FILER_USER
	end
	
	srcVmtMor = rcu.getMoref(SOURCE_VM, "VirtualMachine")
	raise "Source VM: #{SOURCE_VM} not found" unless srcVmtMor
	puts "Source VM: #{SOURCE_VM} (#{srcVmtMor})"
	
	targetHostMor = rcu.getMoref(TARGET_HOST, "HostSystem")
	raise "Source VM: #{TARGET_HOST} not found" unless targetHostMor
	puts "Target host MOR: #{targetHostMor}"
	
	vmFiles = rcu.getVmFiles(srcVmtMor)
	files	= RcuArray.new()
	
	vmFiles.each do |f|		
		files << RcuHash.new("Files") do |nf|
			nf.destDatastoreSpec = RcuHash.new("DestDatastoreSpec") do |dds|
				dds.aggrOrVolName	= "rcu_aggr0"
				dds.controller		= controller
				dds.datastoreNames	= "RichRcuTestTmp"
				dds.numDatastores	= 1
				dds.protocol		= 'NFS'
				dds.sizeInMB		= 1024 * 3
				dds.targetMor		= targetHostMor
				dds.thinProvision	= false
				dds.volAutoGrow		= false
				#
				# volAutoGrowInc and volAutoGrowMax values must be set, even
				# when volAutoGrow is set to false. This is not the case when
				# passing a DestDatastoreSpec to the createDatastore() method,
				# but it is when passing it to the createClones() method.
				# When volAutoGrow is false, the values can be zero.
				#
				dds.volAutoGrowInc	= 0
				dds.volAutoGrowMax	= 0
			end
			nf.sourcePath = f.sourcePath
		end
	end
		
	clones = RcuHash.new("Clones") do |cl|
		cl.entry = RcuArray.new() do |ea|
			ea << RcuHash.new("Entry") do |e|
				e.key	= "RcuCloneTestNewDs1"
				e.value	= ""
			end
			ea << RcuHash.new("Entry") do |e|
				e.key	= "RcuCloneTestNewDs2"
				e.value	= ""
			end
		end
	end
	
	cloneSpec = RcuHash.new("CloneSpec") do |cs|
		cs.clones			= clones
		cs.containerMoref	= targetHostMor
		cs.files			= files
		cs.templateMoref	= srcVmtMor
	end
		
	puts
	puts "Calling createClones..."
	rv = rcu.createClones(cloneSpec)
	
	puts
	puts "*** rv: #{rv} (#{rv.class})"

rescue Handsoap::Fault => hserr
	$stderr.puts hserr.to_s
	$stderr.puts hserr.backtrace.join("\n")
rescue => err
	$stderr.puts err.to_s
	$stderr.puts err.backtrace.join("\n")
end
