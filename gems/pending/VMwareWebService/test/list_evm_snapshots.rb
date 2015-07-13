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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::OFF, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

if ARGV.length != 3
	$stderr.puts "Usage: #{$0} server username password"
	exit 1
end

server		= ARGV[0]
username	= ARGV[1]
password	= ARGV[2]

begin
	puts "Connecting to #{server}..."
	vim = MiqVim.new(server, username, password)
	puts "Done."
	
	puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts

	puts "VMs with EVM snapshots:"
	vim.virtualMachinesByMor.each_value do |vm|
		miqVm = vim.getVimVmByMor(vm['MOR'])
		if miqVm.hasSnapshot?(MiqVimVm::EVM_SNAPSHOT_NAME)
			puts "\t" + miqVm.name
		end
	end
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vim.disconnect
end
