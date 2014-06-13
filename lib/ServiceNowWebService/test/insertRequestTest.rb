$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'SnEccqClientBase'

server = "manageiqdev.service-now.com"
agent = "EVM Automate"
queue = "input"
topic = "Open Incident"
name = "admin"
source = "70.91.104.157"

payload = {
	"id"				=> "Arg0",
	"category"			=> "Arg1",
	"notify"			=> "Arg2",
	"severity"			=> "Arg3",
	"short_description"	=> "Arg4",
	"description"		=> "Arg5"
}

begin
	
	sn = SnEccqClientBase.new(server, "itil", "itil")
	rv = sn.insert(agent, queue, topic, name, source, payload)
	
	puts
	puts "*** RV:"
	sn.dumpObj(rv)

rescue Handsoap::Fault => hserr
	$stderr.puts hserr.to_s
	$stderr.puts hserr.backtrace.join("\n")
rescue => err
	$stderr.puts err.to_s
	$stderr.puts err.backtrace.join("\n")
end
