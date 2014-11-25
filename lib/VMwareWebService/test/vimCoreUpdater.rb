require 'log4r'
require 'MiqVimCoreUpdater'

SERVER   = raise "please define SERVER"
USERNAME = raise "please define USERNAME"
PASSWORD = raise "please define PASSWORD"
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
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

vimEm = MiqVimCoreUpdater.new(SERVER, USERNAME, PASSWORD)

Signal.trap("INT") { vimEm.stop }

begin
    thread = Thread.new do
		vimEm.monitorUpdates do |mor, ph|
			puts "Object: #{mor} (#{mor.vimType})"
			ph.each { |k, v| puts "\t#{k}:\t#{v}"} unless ph.nil?
		end
	end
	thread.join
rescue => err
	puts err.to_s
end
