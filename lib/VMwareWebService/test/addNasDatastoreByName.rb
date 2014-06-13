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
		"**** " + (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

$stdout.sync = true
# $miq_wiredump = true

TARGET_HOST = raise "please define"

DS_NAME		= "nas-ds-add-test"

begin
	
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts

	nasDsa = vim.dataStoresByFilter("summary.type" => "NFS")
	puts "NAS Datastores:"
	nasDsa.each { |ds| puts "\t#{ds.summary.name} (#{ds.summary.url})"}
	puts
	puts "Target datastore: #{DS_NAME}"
	puts
	
	miqHost = vim.getVimHost(TARGET_HOST)
	puts "Got object for host: #{miqHost.name}"
	
	miqDss = miqHost.datastoreSystem
	
	puts
	puts "Adding datastore: #{DS_NAME}..."
	miqDss.addNasDatastoreByName(DS_NAME)
	puts "done."

rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vim.disconnect
end
