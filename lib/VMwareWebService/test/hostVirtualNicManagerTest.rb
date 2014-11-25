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
$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$log.add 'err_console'

# $miq_wiredump = true

# TARGET_HOST = "vi4esxm1.manageiq.com"
TARGET_HOST = raise "please define"
VNIC_DEV	= "vmk1"
hMor = nil

broker = MiqVimBroker.new(:client)
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

	puts "Host name: #{TARGET_HOST}"
    puts
	
	miqHost = vim.getVimHost(TARGET_HOST)

	puts "Host name: #{miqHost.name}"
    puts
	
	vnm = miqHost.hostVirtualNicManager
	
	puts "**** hostVirtualNicManager.info:"
	vim.dumpObj(vnm.info)
	puts "**** END hostVirtualNicManager.info"
	puts
	
	cVnics = vnm.candidateVnicsByType("vmotion")
	
	puts "**** Candidate vnics for vmotion:"
	cVnics.each do |vmn|
		puts "Device: #{vmn.device}, Key: #{vmn.key}"
	end
	puts "**** END Candidate vnics for vmotion"
	puts
	
	selVna = vnm.selectedVnicsByType("vmotion")
	
	puts "**** Selected vnics for vmotion:"
	selVna.each do |vnn|
		puts "Key: #{vnn}"
	end
	puts "**** END Selected vnics for vmotion"
	puts
	
	# svn = selVna.first
	# svd = nil
	# cVnics.each do |cvn|
	# 	if cvn.key == svn
	# 		svd = cvn.device
	# 		break
	# 	end
	# end
	# 
	# puts "**** Deselecting: #{svd}..."
	# vnm.deselectVnicForNicType("vmotion", svd)
	# puts "**** Done."
	# puts
	
	puts "**** Selecting: #{VNIC_DEV}..."
	vnm.selectVnicForNicType("vmotion", VNIC_DEV)
	puts "**** Done."
	puts
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqHost.release if miqHost
    vim.disconnect
end
