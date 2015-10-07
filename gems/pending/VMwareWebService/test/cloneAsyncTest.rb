require_relative '../../bundler_setup'
require 'log4r'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/VimTypes'
require 'VMwareWebService/MiqVimBroker'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
  def format(event)
    (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
  end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level => Log4r::DEBUG, :formatter => ConsoleFormatter)
$vim_log.add 'err_console'

$miq_wiredump = false

$stderr.sync = true
$stdout.sync = true

SRC_VM        = "rpo-clone-src"
# SRC_VM        = "rpo-vmsafe"
TARGET_VM     = "rpo-clone-dest"

VNIC_LABEL    = "Network adapter 1"
NEW_PORTGROUP = "VCB"

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

  puts "VM: #{miqVm.name}, HOST: #{miqVm.hostSystem}"
  puts

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

  memoryMB  = "1024"
  numCPUs   = "1"
  vnicDev   = miqVm.devicesByFilter('deviceInfo.label' => VNIC_LABEL).first

  configSpec = nil
  if vnicDev || memoryMB || numCPUs
    configSpec = VimHash.new('VirtualMachineConfigSpec') do |vmcs|
      vmcs.memoryMB = memoryMB  if memoryMB
      vmcs.numCPUs  = numCPUs if numCPUs
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
            vdcs.device.deviceInfo.summary = NEW_PORTGROUP
            vdcs.device.backing.deviceName = NEW_PORTGROUP

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

  # miqVmf = vim.getVimFolderByMor(vmf["MOR"])
  # puts "\tFound inventory folder: #{miqVmf.name} (#{miqVmf.fMor})"

  puts
  puts "Cloning..."
  taskMor = miqVm.cloneVM(TARGET_VM, vmf, nil, nil, nil, false, false, nil, configSpec, nil, nil, false)

  puts "\tPolling task: #{taskMor}"
  loop do
    state, val = miqVm.pollTask(taskMor)
    case state
    when TaskInfoState::Success
      puts "\t\tClone complete: #{val}"
      break
    when TaskInfoState::Running
      puts "\t\tClone progress: #{val}%" if val
    else
      puts "\t\tClone state: #{state}"
    end
    sleep 4
  end
  puts "done."

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  puts
  puts "Exiting..."
  miqVm.release if miqVm
  vim.disconnect if vim
end
