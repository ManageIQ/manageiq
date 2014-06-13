$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'MiqVim'
require 'log4r'

if !(ARGV.length == 1 && ARGV[0] =~ /(add|remove)/)
    $stderr.puts "Usage: #{$0} add | remove"
    exit 1
end

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

targetVm = raise "please define"
targetVmPath = nil
targetVmLpath = nil

# $DEBUG = true

begin
    vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
	
	puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts
    
    miqVm = vim.getVimVmByFilter("config.name" => targetVm)
	
	targetVmPath = miqVm.dsPath
    
    puts
    puts "Target VM path: #{targetVmPath}"
    
    newVmdk = File.join(File.dirname(targetVmPath), "testDisk.vmdk")
    puts "newVmdk = #{newVmdk}"
    
    puts "********"
    if ARGV[0] == "add"
        miqVm.addDisk(newVmdk, 100)
    else
        miqVm.removeDiskByFile(newVmdk, true)
    end
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
end
