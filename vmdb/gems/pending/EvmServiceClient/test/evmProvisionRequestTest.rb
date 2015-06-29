$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'MiqEvmClientBase'

server = "192.168.252.111"
param0 = "1 MB Template VM"
param1 = "rpo_test10_vm"

begin
	
	evm = MiqEvmClientBase.new(server)
	rv = evm.evmProvisionRequest(param0, param1)
	
	puts "rv = #{rv}, (#{rv.class})"

rescue Handsoap::Fault => hserr
	$stderr.puts hserr.to_s
	$stderr.puts hserr.backtrace.join("\n")
rescue => err
	$stderr.puts hserr.to_s
	$stderr.puts err.backtrace.join("\n")
end
