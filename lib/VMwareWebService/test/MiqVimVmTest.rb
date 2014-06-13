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
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

# TARGET_VM = "rpo-test2"
TARGET_VM = "NetappDsTest2"
ISO_PATH  = "[] /vmimages/tools-isoimages/linux.iso"
vmMor = nil
miqVm = nil

begin
    vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts
    
    miqVm = vim.getVimVmByFilter("summary.config.name" => TARGET_VM)

	# puts miqVm.acquireMksTicket
    # puts vim.acquireCloneTicket.inspect
    
	puts
	puts "Connection State: #{miqVm.connectionState}"
	puts "Power State:      #{miqVm.powerState}"
	
	puts
	puts "extraConfig:"
	vim.dumpObj(miqVm.extraConfig)
	
	exit
	
	nic = miqVm.devicesByFilter("deviceInfo.label" => "Network adapter 1")
	puts "NIC 1: #{nic.first.backing.deviceName}"
	vim.dumpObj(nic)

	# exit
	
	# puts "Powering on VM..."
	# miqVm.start
	# puts "done."
	# 
	# puts "Powering off VM..."
	# miqVm.stop
	# puts "done."
	# 
	# exit
    # 
    # devs = miqVm.devicesByFilter("connectable.connected" => /(false|true)/)
    # devs.each do |dev|
    #     puts dev['deviceInfo']['label']
    # end
    # puts
    # 
    # cd = miqVm.devicesByFilter("deviceInfo.label" => "CD/DVD Drive 1")
    # raise "VM has no CD/DVD drive" if cd.empty?
    # puts "*** Before reconfigure <#{cd[0].xsiType}>:"
    # vim.dumpObj(cd[0])
	# 
	# # vim.logger = $stdout
    # miqVm.connectDevice(cd[0], false, true)
	# # vim.logger = nil
    # miqVm.refresh
    # 
    # cd = miqVm.devicesByFilter("deviceInfo.label" => "CD/DVD Drive 1")
    # raise "VM has no CD/DVD drive" if cd.empty?
    # puts "*** After reconfigure:"
    # vim.dumpObj(cd[0])
    # puts

	cd = miqVm.devicesByFilter("deviceInfo.label" => "CD/DVD Drive 1")
    raise "VM has no CD/DVD drive" if cd.empty?
	cd = cd.first
    puts "*** Before attaching ISO image <#{cd.xsiType}>:"
    vim.dumpObj(cd)
	puts

	puts "Attaching #{ISO_PATH} to CD..."
	miqVm.attachIsoToCd(ISO_PATH, cd)
	puts "done."
	puts
	
	miqVm.refresh
    cd = miqVm.devicesByFilter("deviceInfo.label" => "CD/DVD Drive 1")
    raise "VM has no CD/DVD drive" if cd.empty?
	cd = cd.first
    puts "*** After attaching ISO image <#{cd.xsiType}>:"
    vim.dumpObj(cd)
    puts

	puts "Detaching #{ISO_PATH} from CD..."
	miqVm.resetCd
	puts "done."
	puts
	
	miqVm.refresh
    cd = miqVm.devicesByFilter("deviceInfo.label" => "CD/DVD Drive 1")
    raise "VM has no CD/DVD drive" if cd.empty?
	cd = cd.first
    puts "*** After detaching ISO image <#{cd.xsiType}>:"
    vim.dumpObj(cd)
    puts
    
    exit
    # 
    # vmxSpec = miqVm.vixVmxSpec
    # puts "vmxSpec: #{vmxSpec}"
    #  
    # puts
    # puts "Local Path: #{miqVm.localPath}"
    # 
    # puts
    # ch = miqVm.getCfg
    # puts "**** cfg:"
    # ch.keys.sort.each { |k| puts "#{k}\t=> #{ch[k]}" }
    # puts "**** end cfg"

rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    puts
    puts "Exiting..."
    miqVm.release if miqVm
    vim.disconnect if vim
end
