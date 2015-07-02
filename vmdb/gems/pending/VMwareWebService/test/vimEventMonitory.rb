require 'MiqVimEventMonitor'
require 'log4r'

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

vimEm = MiqVimEventMonitor.new(SERVER, USERNAME, PASSWORD)

Signal.trap("INT") { vimEm.stop }

puts "vimEm.class: #{vimEm.class}"
puts "#{vimEm.server} is #{(vimEm.isVirtualCenter? ? 'VC' : 'ESX')}"
puts "API version: #{vimEm.apiVersion}"

begin
  thread = Thread.new { vimEm.monitorEventsToStdout }
	thread.join
rescue => err
	puts err.to_s
end

puts "done"
