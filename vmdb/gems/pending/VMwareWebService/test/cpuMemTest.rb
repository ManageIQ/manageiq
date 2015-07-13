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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

TARGET_VM = "rpo-test2"
vmMor = nil

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    
    miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)
    
    puts "******* Memory *******"
    
    origMem = miqVm.getMemory
    puts "Memory: #{origMem}"
    
    newMem = (origMem == 256 ? 512 : 256)
    puts "Setting memory to #{newMem}"
    
    miqVm.setMemory(newMem)
    puts "Memory: #{miqVm.getMemory}"
    
    puts "******* CPUs *******"
    
    origCPUs = miqVm.getNumCPUs
    puts "CPUs: #{miqVm.getNumCPUs}"
    
    newCPUs = (origCPUs == 1 ? 2 : 1)
    puts "Setting CPUs to #{newCPUs}"
    
    miqVm.setNumCPUs(newCPUs)
    puts "CPUs: #{miqVm.getNumCPUs}"
    
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vim.disconnect
end
