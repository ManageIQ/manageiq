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

VOL_NAME	= "api_test_vol1"
REMOTE_HOST	= ""
REMOTE_PATH	= "/vol/#{VOL_NAME}"
LOCAL_PATH	= VOL_NAME.tr('_', '-')	# Datastore names cannot contain underscores
ACCESS_MODE	= "readWrite"

begin
    vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts

	miqHost = vim.getVimHost(TARGET_HOST)
	puts "Got object for host: #{miqHost.name}"
	
	miqDss = miqHost.datastoreSystem
	
	puts
	puts "Creating datastore: #{LOCAL_PATH}..."
	miqDss.createNasDatastore(REMOTE_HOST, REMOTE_PATH, LOCAL_PATH, ACCESS_MODE)
	puts "done."

rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vim.disconnect
end
