$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'log4r'
require 'MiqVim'
require 'MiqVimBroker'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

# $DEBUG = true

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
	
    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
	puts

	#
	# Test the AlarmManager
	#
	miqAm = vim.getVimAlarmManager

	alarms = miqAm.getAlarm
	if alarms
		vim.dumpObj(alarms)
	else
		puts "No alarms currently defined"
	end
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqAm.release if miqAm
    vim.disconnect
end
