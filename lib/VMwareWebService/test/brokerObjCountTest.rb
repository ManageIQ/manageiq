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

# $miq_wiredump = true

broker = MiqVimBroker.new(:client)
vim = broker.getMiqVim(SERVER, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

	objs = []
	
	vim.inventoryHash['VirtualMachine'].each	{ |mor| objs << vim.getVimVmByMor(mor) }
	vim.inventoryHash['HostSystem'].each		{ |mor| objs << vim.getVimHostByMor(mor) }
	vim.inventoryHash['Folder'].each			{ |mor| objs << vim.getVimFolderByMor(mor) }
	vim.inventoryHash['Datastore'].each			{ |mor| objs << vim.getVimDataStoreByMor(mor) }
	
	puts
	puts "Object counts:"
	broker.objectCounts.each { |k, v| puts "\t#{k}: #{v}"}
	
	objs.each(&:release)
	
	puts
	puts "Object counts:"
	broker.objectCounts.each { |k, v| puts "\t#{k}: #{v}"}
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqHost.release if miqHost
    vim.disconnect
end
