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

TARGET_HOST = raise "please define"
hMor = nil

broker = MiqVimBroker.new(:client)
vim = broker.getMiqVim(CLIENT, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    miqHost = vim.getVimHost(TARGET_HOST)

	raise "Host has no advanced option manager" if !(aom = miqHost.advancedOptionManager)
	
	puts
	puts "*** Advanced option supportedOption:"
	vim.dumpObj(aom.supportedOption)
	
	puts
	puts "*** Advanced option setting:"
	vim.dumpObj(aom.setting)
	
	puts
	puts "*** Advanced option setting for 'Mem:"
	vim.dumpObj(aom.queryOptions('Mem.'))
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqHost.release if miqHost
    vim.disconnect
end
