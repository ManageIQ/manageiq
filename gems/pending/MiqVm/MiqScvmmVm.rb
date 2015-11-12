require 'MiqVm/MiqVm'
require 'Scvmm/miq_scvmm_vm_ssa_info'

class MiqScvmmVm < MiqVm

  def openDisks(disk_files)
    part_volumes = Array.new

    $log.debug "MiqScvmmVm::openDisks: no disk files supplied." if !disk_files
    raise "MiqScvmmVm::openDisks: Uninitialized miq_scvmm" if @ost.miq_scvmm.nil?
    #
    # Build a list of the VM's physical volumes.
    #
    disk_files.each do |disk_tag, disk_file|
      disk_info = OpenStruct.new
      disk_info.hyperv_connection            = Hash.new
      disk_info.fileName                     = disk_file
      disk_info.hyperv_connection[:host]     = @ost.miq_hyperv[:host]
      disk_info.hyperv_connection[:port]     = @ost.miq_hyperv[:port]
      if @ost.miq_hyperv[:domain].nil?
        disk_info.hyperv_connection[:user] = @ost.miq_hyperv[:user]
      else
        disk_info.hyperv_connection[:user] = @ost.miq_hyperv[:domain] + "\\" + @ost.miq_hyperv[:user]
      end
      disk_info.hyperv_connection[:password] = @ost.miq_hyperv[:password]
 
      mode = @vmConfig.getHash["#{disk_tag}.mode"]
      disk_info.hardwareId = disk_tag
      disk_info.baseOnly   = @ost.openParent unless mode && mode["independent"]
      disk_info.rawDisk    = @ost.rawDisk
    
      begin
        disk = MiqDisk.getDisk(disk_info)
        next if disk.nil?
      rescue => err
        $log.error "Couldn't open disk file: #{diskfile}"
        $log.error err.to_s
        $log.debug err.backtrace.join("\n")
        @diskInitErrors[disk_file] = err.to_s
        next
      end

      part = disk.getPartitions
      if part.empty?
        part_volumes << disk
      else
        part_volumes.concat(part)
      end
    end
    return part_volumes
  end

  def getCfg(snap = nil)

    cfg_hash = {}
    # Collect disk information
    # Call out to the Hyper-V host for Info about the VM.
    host              = @ost.miq_hyperv[:host]
    port              = @ost.miq_hyperv[:port]
    if @ost.miq_hyperv[:domain].nil?
      user = @ost.miq_hyperv[:user]
    else
      user = @ost.miq_hyperv[:domain] + "\\" + @ost.miq_hyperv[:user]
    end
    password          = @ost.miq_hyperv[:password]
    scvmm_info_handle = MiqScvmmVmSSAInfo.new(host, user, password, port)
    vhds              = scvmm_info_handle.vm_all_harddisks(@ost.miq_vm)
    raise "Unable to get Hard Disk Info from VM #{@ost.miq_vm}." unless vhds.any?
    vhds.each do |vhd_attributes|
      vhd      = vhd_attributes["Path"]
      type     = vhd_attributes["ControllerType"].downcase
      number   = vhd_attributes["ControllerNumber"]
      index = vhd_attributes["ControllerLocation"]
      tag = "#{type}#{number}:#{index}"
      cfg_hash["#{tag}.present"]    = "true"
      cfg_hash["#{tag}.devicetype"] = "disk"
      cfg_hash["#{tag}.filename"]   = vhd
    end
    cfg_hash
  end
end
