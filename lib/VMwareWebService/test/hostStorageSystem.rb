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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

$stdout.sync = true
$miq_wiredump = true

TARGET_HOST = raise "please define"
ISCSI_SEND_TARGETS	= [ "10.1.1.100", "10.1.1.210" ]

ISCSI_STATIC_TARGETS = VimArray.new("ArrayOfHostInternetScsiHbaStaticTarget") do |ta|
	ta << VimHash.new("HostInternetScsiHbaStaticTarget") do |st|
		st.address		= "10.1.1.210"
		st.iScsiName	= "iqn.1992-08.com.netapp:sn.135107242"
	end
	ta << VimHash.new("HostInternetScsiHbaStaticTarget") do |st|
		st.address		= "10.1.1.100"
		st.iScsiName	= "iqn.2008-08.com.starwindsoftware:starwindm1-starm1-test1"
	end
end

begin
	vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    
    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts
	
	miqHost = vim.getVimHost(TARGET_HOST)
	puts "Got object for host: #{miqHost.name}"
	
	miqHss = miqHost.storageSystem
	
	softwareInternetScsiEnabled = miqHss.softwareInternetScsiEnabled?
	
	puts
	puts "softwareInternetScsiEnabled: #{softwareInternetScsiEnabled}"
	puts
	
	unless softwareInternetScsiEnabled
		puts "Software iSCSI is disabled. Enabling software iSCSI..."
		miqHss.updateSoftwareInternetScsiEnabled(true)
	end
	puts "done."
	
	hish = miqHss.hostBusAdaptersByType('HostInternetScsiHba').first
	raise "No HostInternetScsiHba found" if hish.nil?
	iScsiHbaDevice = hish.device
	
	puts
	puts "Addedg iSCSI send targets to #{iScsiHbaDevice}..."
	miqHss.addInternetScsiSendTargets(iScsiHbaDevice, ISCSI_SEND_TARGETS)
	puts "done."
	
	puts
	puts "Addedg iSCSI static targets to #{iScsiHbaDevice}..."
	miqHss.addInternetScsiStaticTargets(iScsiHbaDevice, ISCSI_STATIC_TARGETS)
	puts "done."
		
	# puts
	# puts "*** HostInternetScsiHba:"
	# vim.dumpObj(miqHss.hostBusAdaptersByType('HostInternetScsiHba'))

rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vim.disconnect
end
