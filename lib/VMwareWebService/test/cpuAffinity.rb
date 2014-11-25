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

TARGET_VM = "rpo-vmsafe"
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
	puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

	puts
	aa = nil
	if miqVm.vmh['config']['cpuAffinity'] && miqVm.vmh['config']['cpuAffinity']['affinitySet']
		aa = miqVm.vmh['config']['cpuAffinity']['affinitySet']
		puts "CPU affinity for #{TARGET_VM}:"
		aa.each { |cpu| puts "\t#{cpu}" }
	else
		puts "VM: #{TARGET_VM} has no CPU affility"
	end
	puts
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vim.disconnect
end
