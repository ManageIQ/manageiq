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

$miq_wiredump = true

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

CSI_XML_FILE = File.join(File.dirname(__FILE__), "CustomizationSpec", "sles10-x64-vanilla-cust-spec.xml")

begin
	
	puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

	miqCsm = vim.getVimCustomizationSpecManager
	
	# puts "***** encryptionKey:"
	# vim.dumpObj(miqCsm.encryptionKey)
	# puts
	puts "***** info:"
	vim.dumpObj(miqCsm.info)
	
	puts
	puts "***** doesCustomizationSpecExist('Win2K3'):"
	vim.dumpObj(miqCsm.doesCustomizationSpecExist('Win2K3'))
	
	puts
	puts "***** doesCustomizationSpecExist('foo'):"
	vim.dumpObj(miqCsm.doesCustomizationSpecExist('foo'))
	
	puts
	puts "***** CustomizationSpecExist('Win2K3'):"
	csi = miqCsm.getCustomizationSpec('Win2K3')
	vim.dumpObj(csi)
	
	puts
	puts "***** customizationSpecItemToXml:"
	csiXml = miqCsm.customizationSpecItemToXml(csi)
	vim.dumpObj(csiXml)
	
	csiXml = nil
	File.open(CSI_XML_FILE) { |f| csiXml = f.read }
	
	puts
	puts "***** xmlToCustomizationSpecItem:"
	csi = miqCsm.xmlToCustomizationSpecItem(csiXml)
	vim.dumpObj(csi)
	
	if miqCsm.doesCustomizationSpecExist(csi.info.name)
		puts "***** #{csi.info.name} already exists, deleting..."
		miqCsm.deleteCustomizationSpec(csi.info.name)
	end
	
	puts
	puts "***** createCustomizationSpec:"
	vim.dumpObj(miqCsm.createCustomizationSpec(csi))
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqCsm.release if miqCsm
    vim.disconnect
end
