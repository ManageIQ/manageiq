
$:.push("#{File.dirname(__FILE__)}/..")

require 'rubygems'
require 'log4r'
#require 'VimClientBase'
require 'MiqScvmmBroker'

#
# Formatter to output log messages to the console.
#
$stderr.sync = true
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		t = Time.now
		"#{t.hour}:#{t.min}:#{t.sec}: " + (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$log.add 'err_console'

broker = nil

trap(:INT) do
	puts "Connection broker shutting down..."
	broker.shutdown if broker
	puts "Connection broker shutdown complete"
	exit 0
end

# VimClientBase.wiredump_file = "wire_dump.out"
#$miq_wiredump = false

MiqScvmmBroker.preLoad        = true
MiqScvmmBroker.debugUpdates   = false

broker = MiqScvmmBroker.new(:server)
DRb.thread.join
