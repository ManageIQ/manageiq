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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

# $miq_wiredump = true

TARGET_HOST = SERVER
hMor = nil

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

	puts "Host name: #{TARGET_HOST}"
    puts
    
	# puts "**** Host services:"
	# vim.dumpObj(vim.hostSystems[TARGET_HOST]['config']['service'])
	# puts "****************************************************************"
	# puts
	
	miqHost = vim.getVimHost(TARGET_HOST)

	# vim.dumpObj(vim.getMoProp(miqHost.hMor))
	# exit

	puts "Host name: #{miqHost.name}"
    puts

	puts "**** configManager:"
	vim.dumpObj(miqHost.configManager)
	puts "****************************************************************"
	puts
	
	ns = miqHost.networkSystem
	
	puts "**** Refreshing network info..."
	ns.refreshNetworkSystem
	puts "**** Done."
	puts
	
	ni = ns.networkInfo
	
	puts "**** networkInfo:"
	vim.dumpObj(ni)
	puts "****************************************************************"
	puts
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqHost.release if miqHost
    vim.disconnect
end
