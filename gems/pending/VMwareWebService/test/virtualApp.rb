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
		"**** " + (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

$stdout.sync = true
# $miq_wiredump = true

TARGET_HOST = raise "please define"
DS_NAME		= "nas-ds-add-test"

begin
	vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts

	puts "virtualApps from inventoryHash:"
	vim.inventoryHash['VirtualApp'].each do |v|
		puts "\t" + v
	end
	puts
	
	vmh = vim.virtualMachinesByMor
	vma = vim.inventoryHash['VirtualMachine']
	
	puts "virtualAppsByMor:"
	vim.virtualAppsByMor.each do |mor, va|
		puts "\t#{mor}\t-> #{va.name} (parent = #{va.parent})"
		prp = vim.resourcePoolsByMor[va.parent] || vim.virtualAppsByMor[va.parent]
		puts "\t\tParent has child = #{prp.resourcePool.include?(mor)}"
		puts "\t\tVMs:"
		va.vm.each do |vmMor|
			puts "\t\t\t#{vmMor} (In virtualMachinesByMor = #{!vmh[vmMor].nil?}) (In inventoryHash = #{vma.include?(vmMor)})"
		end
	end

rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vim.disconnect
end
