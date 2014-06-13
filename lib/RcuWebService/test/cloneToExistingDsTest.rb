$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'RcuClientBase'

#
# Create 3 clones on existing NFS datastore.
#

VC				= raise "please define"
VC_USER			= raise "please define"
VC_PASSWORD		= raise "please define"

FILER			= raise "please define"
FILER_USER		= raise "please define"
FILER_PASSWORD	= raise "please define"

TARGET_HOST		= raise "please define"
TARGET_DS		= raise "please define"
SOURCE_VM		= raise "please define"

begin
	
	rcu = RcuClientBase.new(VC, VC_USER, VC_PASSWORD)
	
	controller = RcuHash.new("ControllerSpec") do |cs|
		cs.ipAddress	= FILER
		cs.password		= FILER_PASSWORD
		cs.ssl			= false
		cs.username		= FILER_USER
	end
	
	puts
	puts "****"
	srcVmtMor = rcu.getMoref(SOURCE_VM, "VirtualMachine")
	raise "Source VM: #{SOURCE_VM} not found" unless srcVmtMor
	puts "Source VM: #{SOURCE_VM} (#{srcVmtMor})"
	
	targetHostMor = rcu.getMoref(TARGET_HOST, "HostSystem")
	raise "Target host: #{TARGET_HOST} not found" unless targetHostMor
	puts "Target host: #{TARGET_HOST} (#{targetHostMor})"
	
	targetDsMor = rcu.getMoref(TARGET_DS, "Datastore")
	raise "Target datastore: #{TARGET_DS} not found" unless targetDsMor
	puts "Target datastore: #{targetDsMor}"
	puts "****"
	puts
	
	vmFiles = rcu.getVmFiles(srcVmtMor)
	files	= RcuArray.new()
	
	vmFiles.each do |f|		
		files << RcuHash.new("Files") do |nf|
			nf.destDatastoreSpec = RcuHash.new("DestDatastoreSpec") do |dds|
				dds.controller		= controller
				dds.mor				= targetDsMor
				dds.numDatastores	= 0
				dds.thinProvision	= false
				dds.volAutoGrow		= false
			end
			nf.sourcePath = f.sourcePath
		end
	end
		
	clones = RcuHash.new("Clones") do |cl|
		cl.entry = RcuArray.new() do |ea|
			ea << RcuHash.new("Entry") do |e|
				e.key	= "RcuCloneTest1"
				e.value	= ""
			end
			ea << RcuHash.new("Entry") do |e|
				e.key	= "RcuCloneTest2"
				e.value	= ""
			end
			ea << RcuHash.new("Entry") do |e|
				e.key	= "RcuCloneTest3"
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
	puts "*** rv: #{rv} (#{rv.class.to_s})"

rescue Handsoap::Fault => hserr
	$stderr.puts hserr.to_s
	$stderr.puts hserr.backtrace.join("\n")
rescue => err
	$stderr.puts err.to_s
	$stderr.puts err.backtrace.join("\n")
end
