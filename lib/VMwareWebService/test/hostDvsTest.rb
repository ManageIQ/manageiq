$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'log4r'
require 'MiqVim'
require 'VimTypes'
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

$miq_wiredump = false

$stderr.sync = true
$stdout.sync = true

HOST_NAME		= raise "please define"
NEW_PORTGROUP	= 'portgroup2'

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    
    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts

	vimHost = vim.getVimHostByFilter('summary.config.name' => HOST_NAME)
	# vim.dumpObj(vim.hostSystems[HOST_NAME])
	# exit

	hmor = vim.hostSystems[HOST_NAME]['MOR']
	
	#
	# Get the DVS info for a given host.
	#
	dvs = vimHost.dvsConfig
	vim.dumpObj(dvs)
	puts
	
	#
	# List the names of the non-uplink portgroups.
	#
	nupga = vimHost.dvsPortGroupByFilter('uplinkPortgroup' => 'false')
	puts "Available DVS portgroups:"
	nupga.each { |nupg| puts "\t" + nupg.portgroupName }
	puts
	
	dpg = vimHost.dvsPortGroupByFilter('portgroupName' => NEW_PORTGROUP, 'uplinkPortgroup' => 'false').first
	switchUuid		= dpg.switchUuid
	portgroupName	= dpg.portgroupName
	portgroupKey	= dpg.portgroupKey
	puts "portgroupName: #{portgroupName}, portgroupKey: #{portgroupKey}, switchUuid: #{switchUuid}"
    
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    puts
    puts "Exiting..."
	vimHost.release if vimHost
    vim.disconnect if vim
end
