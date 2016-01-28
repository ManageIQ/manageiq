# encoding: US-ASCII

require 'util/miq_winrm'
require 'Scvmm/miq_scvmm_parse_powershell'

class MiqScvmmVmSSAInfo
  attr_reader :vhds, :hostname, :checkpoints, :vhd_type
  def initialize(provider, user, pass, port = nil)
    @checkpoints = []
    @vhds        = []
    @hostname    = nil
    @vhd_type    = nil
    @winrm       = MiqWinRM.new
    winrmport    = port.nil? ? 5985 : port
    options      = {:port => winrmport, :user => user, :pass => pass, :hostname => provider}

    @winrm.connect(options)
    @parser = MiqScvmmParsePowershell.new
  end

  def vm_host(vm_name)
    host_script = <<-HOST_EOL
Get-SCVirtualMachine -VMMServer localhost -Name "#{vm_name}" | \
  Select-Object -ExpandProperty Hostname
HOST_EOL

    @hostname, stderr = @parser.parse_single_powershell_value(@winrm.run_powershell_script(host_script))
    raise "Unable to obtain Host for #{vm_name}" if stderr =~ /At line:/
    @hostname
  end

  # Note the following method returns *all* hard disks and some common attributes from the Hyper-V host
  def vm_all_harddisks(vm_name, snapshot = nil, check_snapshot = TRUE)
    vhds       = vm_get_disks(vm_name, snapshot, check_snapshot)
    properties = vm_get_properties(vm_name)
    raise "Error getting VHD(s) and Attributes for #{vm_name}" if vhds.size != properties.size
    raise "No Virtual Hard Disk found for VM #{vm_name}" unless vhds.any?

    i = 0
    new_vhds = []
    $log.debug "vm_all_harddisks: #{vhds.size} vhds found:\n"
    vhds.each do |vhd|
      vhd.merge!(properties[i])
      new_vhds << vhd
      i += 1
    end
    new_vhds
  end

  def vm_vhdtype(vm_name)
    vhdtype_script = <<-VHDTYPE_EOL
Get-SCVirtualHardDisk -VMMServer localhost -VM "#{vm_name}" | \
  Select-Object -ExpandProperty VHDType
VHDTYPE_EOL

    @vhd_type, stderr = @parser.parse_single_powershell_value(@winrm.run_powershell_script(vhdtype_script))
    raise "Unable to obtain VHD Type for #{vm_name}" if stderr =~ /At line:/
    @vhd_type
  end

  def vm_get_checkpoint(vm_name, snapshot)
    get_checkpoint_script = <<-GETCHECKPOINT_EOL
Get-VMSnapShot -ComputerName localhost -VMName "#{vm_name}" -Name "#{snapshot}"| \
  Select-Object -ExpandProperty Name
GETCHECKPOINT_EOL

    checkpoint, stderr = @parser.parse_single_powershell_value(@winrm.run_powershell_script(get_checkpoint_script))
    return nil if stderr =~ /Unable to find a snapshot/
    checkpoint
  end

  def vm_create_evm_checkpoint(vm_name, snapshot = nil)
    snapshot = vm_name + "__EVM_SNAPSHOT" if snapshot.nil?
    raise "Checkpoint for VM #{vm_name} Already Exists" unless vm_get_checkpoint(vm_name, snapshot).nil?

    checkpoint_script = <<-CHECKPOINT_EOL
Checkpoint-VM -ComputerName localhost -Name "#{vm_name}" -SnapshotName "#{snapshot}"
CHECKPOINT_EOL

    _stdout, stderr = @parser.parse_single_powershell_value(@winrm.run_powershell_script(checkpoint_script))
    raise "Unable to create Snapshot for #{vm_name}" if stderr =~ /At line:/
    snapshot
  end

  def vm_remove_evm_checkpoint(vm_name, snapshot = nil)
    snapshot = vm_name + "__EVM_SNAPSHOT" if snapshot.nil?
    rm_checkpoint_script = <<-RM_CHECKPOINT_EOL
Remove-VMSnapshot -ComputerName localhost -VMName "#{vm_name}" -Name "#{snapshot}"
RM_CHECKPOINT_EOL

    _stdout, stderr = @parser.parse_single_powershell_value(@winrm.run_powershell_script(rm_checkpoint_script))
    raise "Unable to remove Snapshot for #{vm_name}" if stderr =~ /At line:/
  end

  private

  def vm_get_properties(vm_name)
    properties_script = <<-PROPERTIES_EOL
Get-VMHardDiskDrive -VMName "#{vm_name}" | \
  Format-Table -Property ControllerType,ControllerNumber,ControllerLocation -Autosize
PROPERTIES_EOL

    properties, stderr = @parser.parse_multiple_attribute_values(@winrm.run_powershell_script(properties_script))
    raise "Error getting VHD(s) and Attributes for #{vm_name}" if stderr =~ /At line:/
    properties
  end

  def vm_get_disks(vm_name, snapshot, check_snapshot)
    if check_snapshot.nil?
      vhd_script = <<-VHD_EOL
Get-VMHardDiskDrive -VMName "#{vm_name}" | \
  Format-Table -Property Path | out-string -Width 200
VHD_EOL
    else
      snapshot = vm_name + "__EVM_SNAPSHOT" if snapshot.nil?
      raise "Checkpoint #{snapshot} for VM #{vm_name} missing" if vm_get_checkpoint(vm_name, snapshot).nil?
      vhd_script = <<-SNAP_EOL
Get-VMSnapShot -VMName "#{vm_name}" -Name "#{snapshot}" |  Get-VMHardDiskDrive | \
  Format-Table -Property Path | out-string -Width 200
SNAP_EOL
    end

    vhds, stderr = @parser.parse_single_attribute_values(@winrm.run_powershell_script(vhd_script))
    raise "Unable to obtain VHD Name(s) for #{vm_name}" if stderr =~ /At line:/
    vhds
  end
end
