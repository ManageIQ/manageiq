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

TARGET_VM = raise "please define"
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
	puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

	puts
	puts "** VM annotation start:"
	puts miqVm.annotation
	puts "** VM annotation end"
	
	puts
	puts "Custom values:"
	miqVm.customValues.each { |k, v| puts "\t#{k} => #{v}"}
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vim.disconnect
end
