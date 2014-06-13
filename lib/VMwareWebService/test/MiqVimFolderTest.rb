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

$stderr.sync = true
$stdout.sync = true

TARGET_VM      = "rpo-clone-src"
sVmMor = nil
miqVm = nil

vimDs = nil
dsName = "DEVOpen-E0"

begin
    vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts

	miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)
	
	vmMor	= miqVm.vmMor
	rpMor	= miqVm.vmh.resourcePool
	hsMor	= miqVm.vmh.summary.runtime.host
	vmPath	= miqVm.vmh.summary.config.vmPathName
	
	puts "Target VM: #{TARGET_VM}, MOR: #{vmMor}"
	puts "Target VM path: #{vmPath}"
	puts "VM resource pool MOR: #{rpMor}"
	puts "VM host MOR: #{hsMor}"
	puts
	
	miqVmf = vim.getVimFolderByFilter('childType' => 'VirtualMachine', 'childEntity' => vmMor)
	# vim.dumpObj(miqVmf.fh)
        
	puts "Unregistering #{TARGET_VM}..."
	miqVm.unregister
	puts "Done."
        
    puts
    puts "Registering VM #{TARGET_VM}..."
    miqVmf.registerVM(vmPath, TARGET_VM, rpMor, hsMor, false)
    puts "done."
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    puts
    puts "Exiting..."
    miqVm.release if miqVm
    vim.disconnect if vim
end
