require 'rubygems'
require 'log4r'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$log.add 'err_console'

$stdout.sync = true

require_relative '../SlpLib_raw'

begin
	
	slph = SlpLib_raw.open(nil, false)
	srvs = SlpLib_raw.findSrvs(slph, "service:wbem", nil, nil)
	
	srvs.each do |s|
		puts "*** Server :#{s}"
		attrs = SlpLib_raw.findAttrs(slph, s, nil, nil)
		
		aa = attrs[1...-1].split("),(")
		h = {}
		aa.each { |a| h.store(*a.split("=")) }
		h.each { |k,v| puts "\t#{k} => #{v}" }
		puts "***"
		puts
	end
	SlpLib_raw.close(slph)
	
rescue => err
	$stderr.puts err
	$stderr.puts err.backtrace.join("\n")
end