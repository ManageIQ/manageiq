require 'MiqVm/MiqVm'
require 'disk/modules/AzureBlobDisk'

class MiqAzureVm < MiqVm
  def initialize(azure_handle, args)
    @azure_handle = azure_handle
    @uri          = nil

    raise ArgumentError, "MiqAzureVm: missing required arg :name" unless (@name = args[:name])

    if args[:image_uri]
      @uri = args[:image_uri]
    elsif args[:resource_group] && args[:name]
      vm_obj = vm_svc.get(@name, args[:resource_group])
      @uri = vm_obj.properties.storage_profile.os_disk.vhd.uri
    else
      raise ArgumentError, "MiqAzureVm: missing required args: :image_uri or :resource_group"
    end

    super(getCfg)
  end

  def getCfg
    cfg_hash = {}
    cfg_hash['displayname'] = @name

    $log.debug "MiqAzureVm#getCfg: disk = #{@uri}"

    tag = "scsi0:0"
    cfg_hash["#{tag}.present"]    = "true"
    cfg_hash["#{tag}.devicetype"] = "disk"
    cfg_hash["#{tag}.filename"]   = @uri

    cfg_hash
  end

  def openDisks(diskFiles)
    p_volumes = []

    $log.debug "openDisks: no disk files supplied." unless diskFiles

    #
    # Build a list of the VM's physical volumes.
    #
    diskFiles.each do |dtag, df|
      $log.debug "openDisks: processing disk file (#{dtag}): #{df}"
      dInfo = OpenStruct.new

      dInfo.fileName   = df
      dInfo.hardwareId = dtag
      disk_format = @vmConfig.getHash["#{dtag}.format"]
      dInfo.format = disk_format unless disk_format.blank?

      mode = @vmConfig.getHash["#{dtag}.mode"]

      dInfo.hardwareId = dtag
      dInfo.rawDisk = true

      begin
        d = AzureBlobDisk.new(sa_svc, @uri, dInfo)
      rescue => err
        $log.error "Couldn't open disk file: #{df}"
        $log.error err.to_s
        $log.debug err.backtrace.join("\n")
        @diskInitErrors[df] = err.to_s
        next
      end

      @wholeDisks << d
      p = d.getPartitions
      if p.empty?
        #
        # If the disk has no partitions, the whole disk can be a single volume.
        #
        p_volumes << d
      else
        #
        # If the disk is partitioned, the partitions are physical volumes,
        # but not the whild disk.
        #
        p_volumes.concat(p)
      end
    end

    p_volumes
  end # def openDisks

  def vm_svc
    @vm_svc ||= Azure::Armrest::VirtualMachineService.new(@azure_handle)
  end

  def sa_svc
    @sa_svc ||= Azure::Armrest::StorageAccountService.new(@azure_handle)
  end
end
