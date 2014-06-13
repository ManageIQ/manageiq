$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'RcuClientBase'

VC				= raise "please define"
VC_USER			= raise "please define"
VC_PASSWORD		= raise "please define"

SOURCE_VM		= raise "please define"

begin
	
	rcu = RcuClientBase.new(VC, VC_USER, VC_PASSWORD)
	
	puts
	puts "****"
	srcVmtMor = rcu.getMoref(SOURCE_VM, "VirtualMachine")
	raise "Source VM: #{SOURCE_VM} not found" unless srcVmtMor
	puts "Source VM: #{SOURCE_VM} (#{srcVmtMor})"
	puts "****"
		
	puts
	puts "Calling getVms..."
	rv = rcu.getVms(srcVmtMor)
	
	puts
	puts "VMs flex-cloned from #{SOURCE_VM}:"
	rv.each { |v| puts "\t#{v.vmMoref}" }

rescue Handsoap::Fault => hserr
	$stderr.puts hserr.to_s
	$stderr.puts hserr.backtrace.join("\n")
rescue => err
	$stderr.puts err.to_s
	$stderr.puts err.backtrace.join("\n")
end
