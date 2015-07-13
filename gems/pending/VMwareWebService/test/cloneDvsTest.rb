$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'log4r'
require 'MiqVim'
require 'VimTypes'
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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

$miq_wiredump = false

$stderr.sync = true
$stdout.sync = true

SRC_VM			= "nondeploy"
TARGET_VM      	= "rpo-nondeploy"

HOST_NAME		= raise "please define"

VNIC_LABEL		= "Network adapter 1"
NEW_PORTGROUP	= 'portgroup2'

sVmMor = nil
miqVm = nil

vimDs = nil
dsName = "DEVOpen-E0"

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts
    
    #
    # Get the source VM.
    #
    miqVm = vim.getVimVmByFilter("config.name" => SRC_VM)

	puts "#{SRC_VM} vmPathName:      #{miqVm.dsPath}"
	puts "#{SRC_VM} vmLocalPathName: #{miqVm.localPath}"
    
    puts "VM: #{miqVm.name}, HOST: #{miqVm.hostSystem} #{miqVm.hostSystem.vimType}"
    puts

	hmor = vim.hostSystems[HOST_NAME]['MOR']
	
	#
	# Get the DVS info for a given host.
	#
	dvs = vim.queryDvsConfigTarget(vim.sic.dvSwitchManager, hmor, nil)
	
	#
	# List the names of the non-uplink portgroups.
	#
	nupga = vim.applyFilter(dvs.distributedVirtualPortgroup, 'uplinkPortgroup' => 'false')
	puts "Available DVS portgroups:"
	nupga.each { |nupg| puts "\t" + nupg.portgroupName }
	puts
	
	dpg = vim.applyFilter(dvs.distributedVirtualPortgroup, 'portgroupName' => NEW_PORTGROUP, 'uplinkPortgroup' => 'false').first
	switchUuid		= dpg.switchUuid
	portgroupName	= dpg.portgroupName
	portgroupKey	= dpg.portgroupKey
	puts "portgroupName: #{portgroupName}, portgroupKey: #{portgroupKey}, switchUuid: #{switchUuid}"
	# vim.dumpObj(dvs)
	# exit
	
    #
    # See if the target VM already exists.
    #
	begin
    	dMiqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

        puts "Target VM: #{TARGET_VM} already exists"
        puts "\tDeleting #{TARGET_VM}..."
        dMiqVm.destroy
        puts "done."
        exit
	rescue
		# Ignore expectd error
    end

	puts "Preparing to clone: #{SRC_VM} to #{TARGET_VM}"

	memoryMB	= "1024"
	memoryMB	= nil
	numCPUs		= "1"
	numCPUs		= nil
	vnicDev		= miqVm.devicesByFilter('deviceInfo.label' => VNIC_LABEL).first
	# vim.dumpObj(vnicDev)
	# exit
	
	configSpec = nil
	if vnicDev || memoryMB || numCPUs
		configSpec = VimHash.new('VirtualMachineConfigSpec') do |vmcs|
			vmcs.memoryMB	= memoryMB	if memoryMB
			vmcs.numCPUs	= numCPUs	if numCPUs
			if vnicDev
				vmcs.deviceChange = VimArray.new('ArrayOfVirtualDeviceConfigSpec') do |vdcsa|
					vdcsa << VimHash.new('VirtualDeviceConfigSpec') do |vdcs|
						vdcs.operation = VirtualDeviceConfigSpecOperation::Edit
						#
						#  deepClone should be made client-side when using DRB.
						#
						vdcs.device = vim.deepClone(vnicDev)
						
						#
						# Change the port group of the target VM.
						#
						vdcs.device.deviceInfo.summary = portgroupName
						# vdcs.device.backing.deviceName = NEW_PORTGROUP
						vdcs.device.backing = VimHash.new('VirtualEthernetCardDistributedVirtualPortBackingInfo') do |vecdvpbi|
							vecdvpbi.port = VimHash.new('DistributedVirtualSwitchPortConnection') do |dvspc|
								dvspc.switchUuid	= switchUuid
								dvspc.portgroupKey	= portgroupKey
							end
						end
						
						#
						# Manually assign MAC address to target VM.
						#
						vdcs.device.macAddress = '00:50:56:8a:47:ff'
						vdcs.device.addressType = 'Manual'
					end
				end
			else
				puts "Not changing port group."
			end
		end
	end
    
    #
    # Find a VIM inventory folder to put the VM in.
    #
	# vim.dumpObj(vim.foldersByMor)
    # vmfa = vim.foldersByFilter("childType" => "VirtualMachine", "name" => "vm")
	vmfa = vim.foldersByFilter("name" => "vm")
    raise "VM inventory folder not found" if vmfa.empty?
    vmf = vmfa[0]
    
    miqVmf = vim.getVimFolderByMor(vmf["MOR"])
    puts "\tFound inventory folder: #{miqVmf.name} (#{miqVmf.fMor})"
    
    puts
    puts "Cloning..."
    miqVm.cloneVM(TARGET_VM, vmf, nil, nil, nil, false, false, nil, configSpec)
    puts "done."

	exit

	#
    # Get the target VM.
    #
    tvm = vim.virtualMachinesByFilter("config.name" => TARGET_VM)
    if tvm.empty?
        puts "VM: #{TARGET_VM} not found"
        exit
    end

	if (vmp = tvm[0]['summary']['config']['vmPathName'])
		puts "#{TARGET_VM} vmPathName:      #{vmp}"
	else
		puts "#{TARGET_VM} vmPathName is not set"
	end
		
	if (vmlp = tvm[0]['summary']['config']['vmLocalPathName'])
		puts "#{TARGET_VM} vmLocalPathName: #{vmlp}"
	else
		puts "#{TARGET_VM} vmLocalPathName is not set"
	end
	
	exit if !vmp || !vmlp
	
	puts "#{TARGET_VM} not hashed by #{vmp}"  if !vim.virtualMachines[vmp]
	puts "#{TARGET_VM} not hashed by #{vmlp}" if !vim.virtualMachines[vmlp]
    
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    puts
    puts "Exiting..."
    miqVm.release if miqVm
    vim.disconnect if vim
end
