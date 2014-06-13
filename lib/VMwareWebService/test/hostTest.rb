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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::OFF, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

# $miq_wiredump = true

TARGET_HOST = raise "please define"
hMor = nil

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    miqHost = vim.getVimHost(TARGET_HOST)

	puts "*** systemInfo"
	vim.dumpObj(miqHost.hh['hardware']['systemInfo'])
	exit

	puts "*** quickStats"
	qs = miqHost.quickStats
	vim.dumpObj(qs)
	exit

	vim.dumpObj(miqHost.hh['config']['dateTimeInfo'])
	puts "miqHost: #{miqHost.class.to_s}"
	exit

	puts "Host name: #{miqHost.name}"
    puts
	puts "**** fileSystemVolume:"
	vim.dumpObj(miqHost.fileSystemVolume)
	puts
	puts "**** storageDevice:"
	vim.dumpObj(miqHost.storageDevice)
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqHost.release if miqHost
    vim.disconnect
end
