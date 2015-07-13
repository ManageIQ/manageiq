$:<< ".."
require 'MiqVimInventory'
require 'log4r'

SERVER   = raise "please define SERVER"
USERNAME = raise "please define USERNAME"
PASSWORD = raise "please define PASSWORD"

$stderr.sync = true
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		t = Time.now
		"#{t.hour}:#{t.min}:#{t.sec}: " + (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

# $miq_wiredump				= true
vim = MiqVimInventory.new(SERVER, USERNAME, PASSWORD)

puts
puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
puts "API version: #{vim.apiVersion}"
puts

puts "folders.length:              #{vim.folders.length}"
puts "virtualMachines.length:      #{vim.virtualMachines.length}"
puts "virtualMachinesByMor.length: #{vim.virtualMachinesByMor.length}"

vim.disconnect
