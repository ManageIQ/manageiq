$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
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
TARGET_VM = "NetAppDsTest7"

begin
    broker = MiqVimBroker.new(:client)
	if !broker.serverAlive?
		puts "Broker server isn't running"
		exit
	end

	t0 = Time.now
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
	t1 = Time.now
	
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts
	puts "Inventory load time: #{t1 - t0}"
	
	# exit
	
	# puts
	# puts broker.connectionInfo.inspect
	
	puts
	puts "logging broker status..."
	broker.logStatus
	puts "done."

    # puts
    # puts "Loading VMs..."
	# t1 = Time.now
	
	# vms = vim.virtualMachinesByMor
	
	# t2 = Time.now
    # puts "VM load complete."
	# 
	# puts "Number of VMs: #{vms.keys.length}"
	# puts "VM load (transfer) time: #{t2 - t1}"
	# puts
	# puts "Total time: #{t2 - t0}"
	
	# exit
	
	puts
    puts "Resetting cache..."
	vim.resetCache
	
	puts
    puts "Loading VMs..."
	t1 = Time.now
	
	# vim.receiveTimeout = 0
	vms = vim.virtualMachinesByMor
	
	t2 = Time.now
    puts "VM load complete."
	
	puts "Number of VMs: #{vms.keys.length}"
	puts "VM load (transfer) time: #{t2 - t1}"
	puts
	
	# exit
	
	vimVm = vim.getVimVmByMor(vms.values.first['MOR'])
	
	broker.logStatus
	
	# broker.removeMiqVim(vim.server, vim.username)
	# exit
	
	vimVm.release
	
	broker.logStatus
	
	# exit
	
    # vim.resetCache
    # vim.dumpAll
    
    # exit

    vim.virtualMachines.each do |n, o|
        next if vim.dsPath?(n)
        # puts
        puts "********* #{n}"
        puts "Original local path: #{n}"
        # puts "\tConverted to DS path: #{vim.datastorePath(n)}"
        # puts "Original DS path: #{o['config']['vmPathName']}"
        # puts "\tConverted to local path: #{vim.localVmPath(o['config']['vmPathName'])}"
        # vim.dumpObj(o)
    end

    puts
    vim.inventoryHash.each do |k, v|
    	puts
        puts "#{k}:"
        v.each do |mor|
            # puts
            puts "******** #{mor}"
            props = vim.getMoProp(mor)
            # vim.dumpObj(props)
        end
    end
rescue => err
    puts err
	puts err.class.to_s
    puts err.backtrace.join("\n")
end
