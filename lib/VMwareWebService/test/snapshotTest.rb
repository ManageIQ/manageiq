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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

$stdout.sync = true

TARGET_VM = "AAA2206"
vmMor = nil

begin
    vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
	puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts
    
	miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)
	
	puts "Has EvmSnapshot: #{miqVm.hasSnapshot?('EvmSnapshot')}"
	miqVm.removeAllSnapshots
	exit

	puts
	puts "*** START Snapshot info from vim.virtualMachines"
	vim.dumpObj(miqVm.vmh['snapshot'])
	puts "*** END Snapshot info from vim.virtualMachines"
	puts
	        
    ssInfo = miqVm.snapshotInfo
    
    if ssInfo
        # vim.dumpObj(ssInfo)
        hasCh = miqVm.hasSnapshot?("Consolidate Helper", true)
        puts "Has Consolidate Helper = #{hasCh}"
        # exit
    
        ssHash = ssInfo['ssMorHash']
        curSnapshot = ssHash[ssInfo['currentSnapshot'].to_s]['snapshot']
        puts
        puts "curSnapshot = #{curSnapshot}"
        puts "curSnapshot name = #{ssHash[ssInfo['currentSnapshot'].to_s]['name']}"
        puts "++++++++++++++ snapshot props from tree +++++++++++++++++++++++++++"
        vim.dumpObj(ssInfo)
        puts "+++++++++++++++ end snapshot props from tree ++++++++++++++++++++++++++"
    else
        puts "No snapshots found"
    end
    
    snMor = miqVm.createSnapshot("rpoTest", "test snapshot", false, "false")
    puts "snMor = #{snMor}"
    
    miqVm.removeSnapshot(snMor)
    #miqVm.removeSnapshot(String.new(snMor.to_s))
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vim.disconnect
end
