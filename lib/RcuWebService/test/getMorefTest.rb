$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'RcuClientBase'

VC				= raise "please define"
VC_USER			= raise "please define"
VC_PASSWORD		= raise "please define"
VM_NAME = raise "please define"
begin
	
	rcu = RcuClientBase.new(VC, VC_USER, VC_PASSWORD)
	
	puts
	puts "Calling getMoref..."
	rv = rcu.getMoref(VM_NAME, "VirtualMachine")
	puts
	puts "*** RV: #{rv} (#{rv.class.to_s})"
	
	vimMor = rcu.rcuMorToVim(rv)
	puts "*** VIM MOR: vimType = #{vimMor.vimType}, val = #{vimMor}"
	
	rcuMor = rcu.vimMorToRcu(vimMor)
	puts "*** RCU MOR: vimType = #{rcuMor}"

rescue Handsoap::Fault => hserr
	$stderr.puts hserr.to_s
	$stderr.puts hserr.backtrace.join("\n")
rescue => err
	$stderr.puts err.to_s
	$stderr.puts err.backtrace.join("\n")
end
