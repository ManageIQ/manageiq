$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'log4r'
require 'MiqVim'

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

TARGET_VM = "rich-vmsafe-enabled"
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
	
	puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

	puts "VM UUID: #{miqVm.vmh['config']['uuid']}"

	puts
	if miqVm.vmsafeEnabled?
		vmsAttr = miqVm.getVmSafeAttributes
		puts "vmsafe.enable:       #{vmsAttr['enable']}"
		puts "vmsafe.agentAddress: #{vmsAttr['agentAddress']}"
		puts "vmsafe.agentPort:    #{vmsAttr['agentPort']}"
		puts "vmsafe.failOpen:     #{vmsAttr['failOpen']}"
		puts "vmsafe.immutableVM:  #{vmsAttr['immutableVM']}"
		puts "vmsafe.timeoutMS:    #{vmsAttr['timeoutMS']}"
	else
		puts "VM is not vmsafe enabled"
	end
	
	miqVm.setVmSafeAttributes('enable' => "true", 'timeoutMS' => "6000000", 'agentAddress' => "192.168.252.146", 'agentPort' => '8888')
	miqVm.refresh
	
	puts
	if miqVm.vmsafeEnabled?
		vmsAttr = miqVm.getVmSafeAttributes
		puts "vmsafe.enable:       #{vmsAttr['enable']}"
		puts "vmsafe.agentAddress: #{vmsAttr['agentAddress']}"
		puts "vmsafe.agentPort:    #{vmsAttr['agentPort']}"
		puts "vmsafe.failOpen:     #{vmsAttr['failOpen']}"
		puts "vmsafe.immutableVM:  #{vmsAttr['immutableVM']}"
		puts "vmsafe.timeoutMS:    #{vmsAttr['timeoutMS']}"
	else
		puts "VM is not vmsafe enabled"
	end
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vim.disconnect
end
