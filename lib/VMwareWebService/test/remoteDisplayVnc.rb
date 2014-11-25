$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'log4r'
require 'MiqVim'
# require 'MiqVimBroker'

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

TARGET_VM = "testxav"
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
	
	puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

	puts "VM UUID: #{miqVm.vmh['config']['uuid']}"

	puts
	if miqVm.remoteDisplayVncEnabled?
		vmsAttr = miqVm.getRemoteDisplayVncAttributes
		puts "RemoteDisplay.vnc.enabled:  #{vmsAttr['enabled']}"
		puts "RemoteDisplay.vnc.key:      #{vmsAttr['key']}"
		puts "RemoteDisplay.vnc.password: #{vmsAttr['password']}"
		puts "RemoteDisplay.vnc.port:     #{vmsAttr['port']}"
	else
		puts "VM RemoveDisplay.vnc is not enabled"
	end
	
	miqVm.setRemoteDisplayVncAttributes('enabled' => "true", 'password' => PASSWORD, 'port' => 5901)
	miqVm.refresh
	
	puts
	if miqVm.remoteDisplayVncEnabled?
		vmsAttr = miqVm.getRemoteDisplayVncAttributes
		puts "RemoteDisplay.vnc.enabled:  #{vmsAttr['enabled']}"
		puts "RemoteDisplay.vnc.key:      #{vmsAttr['key']}"
		puts "RemoteDisplay.vnc.password: #{vmsAttr['password']}"
		puts "RemoteDisplay.vnc.port:     #{vmsAttr['port']}"
	else
		puts "VM RemoveDisplay.vnc vnc is not enabled"
	end
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vim.disconnect
end
