require 'cim_profile_defs'

class MiqCimHostSystem < MiqCimInstance

  virtual_has_many  :datastore_backing,     :class_name => 'MiqCimInstance'
  virtual_has_many  :storage_systems,     :class_name => 'CimComputerSystem'
  virtual_has_many  :file_shares,       :class_name => 'SniaFileShare'
  virtual_has_many  :storage_volumes,     :class_name => 'CimStorageVolume'
  virtual_has_many  :file_systems,        :class_name => 'SniaLocalFileSystem'
  virtual_has_many  :logical_disks,       :class_name => 'CimLogicalDisk'
  virtual_has_many  :base_storage_extents,    :class_name => 'CimStorageExtent'

  virtual_column    :base_storage_extents_size, :type => :integer
  virtual_column    :file_shares_size,      :type => :integer
  virtual_column    :cim_datastores_size,   :type => :integer
  virtual_column    :storages_size,       :type => :integer
  virtual_column    :cim_vms_size,        :type => :integer
  virtual_column    :vms_size,          :type => :integer
  virtual_column    :logical_disks_size,    :type => :integer

  HostToBaseSe        = CimProfiles.host_to_base_storage_extent
  HostToLfs         = CimProfiles.host_to_filesystem
  HostToDatastore       = CimAssociations.MIQ_CimHostSystem_TO_MIQ_CimDatastore
  HostToVm          = CimAssociations.MIQ_CimHostSystem_TO_MIQ_CimVirtualMachine

  HostToFileShareShortcut   = CimAssociations.MIQ_CimHostSystem_TO_SNIA_FileShare_SC
  HostToStorageVolumeShortcut = CimAssociations.MIQ_CimHostSystem_TO_CIM_StorageVolume_SC
  HostToCcsShortcut     = CimAssociations.MIQ_CimHostSystem_TO_CIM_ComputerSystem_SC
  HostToLfsShortcut     = CimAssociations.MIQ_CimHostSystem_TO_SNIA_LocalFileSystem_SC
  HostToLogicalDiskShortcut = CimAssociations.MIQ_CimHostSystem_TO_CIM_LogicalDisk_SC
  HostToBseShortcut     = CimAssociations.MIQ_CimHostSystem_TO_CIM_StorageExtent_SC

  SHORTCUT_DEFS = {
    :local_file_systems_long  => HostToLfsShortcut,
    :base_storage_extents_long  => HostToBseShortcut
  }

  #########################
  # Datastore associations
  #########################

  #
  # No shortcut needed, direct associations.
  #
  def cim_datastores
    getAssociators(HostToDatastore)
  end

  def cim_datastores_size
    getAssociationSize(HostToDatastore)
  end

  def storages
    getAssociatedVmdbObjs(HostToDatastore)
  end

  def storages_size
    getAssociationSize(HostToDatastore)
  end

  ##################
  # VM associations
  ##################

  #
  # No shortcut needed, direct associations.
  #
  def cim_vms
    getAssociators(HostToVm)
  end

  def cim_vms_size
    getAssociationSize(HostToVm)
  end

  def vms
    getAssociatedVmdbObjs(HostToVm)
  end

  def vms_size
    getAssociationSize(HostToVm)
  end

  ##########################
  # File Share associations
  ##########################

  #
  # Association created by SniaFileShare class.
  #
  def file_shares
    getAssociators(HostToFileShareShortcut)
  end

  def file_shares_size
    getAssociationSize(HostToFileShareShortcut)
  end

  ####################################
  # Storage Volume (LUN) associations
  ####################################

  #
  # Association created by CimStorageVolume class.
  #
  def storage_volumes
    getAssociators(HostToStorageVolumeShortcut)
  end

  def storage_volumes_size
    getAssociationSize(HostToStorageVolumeShortcut)
  end

  #
  # Backing - file shares and/or storage volumes.
  #
  def datastore_backing
    file_shares + storage_volumes
  end

  def datastore_backing_size
    file_shares_size + storage_volumes_size
  end

  ##############################
  # Storage system associations
  ##############################

  #
  # Association created by CimComputerSystem class.
  #
  def storage_systems
    getAssociators(HostToCcsShortcut)
  end

  def storage_systems_size
    getAssociationSize(HostToCcsShortcut)
  end

  ##########################
  # Filesystem associations
  ##########################

  def local_file_systems_long
    dh = {}
    getLeafNodes(HostToLfs, self, dh)
    dh.values.compact.uniq.delete_if { |ae| !ae.kinda?("SNIA_LocalFileSystem") }
  end

  def local_file_systems
    getAssociators(HostToLfsShortcut)
  end

  def local_file_systems_size
    getAssociationSize(HostToLfsShortcut)
  end

  # Old name - should change
  def file_systems
    local_file_systems
  end

  ############################
  # Logical Disk associations
  ############################

  def logical_disks
    getAssociators(HostToLogicalDiskShortcut)
  end

  def logical_disks_size
    getAssociationSize(HostToLogicalDiskShortcut)
  end

  #####################################################
  # Base Storage Extent (primordial disk) associations
  #####################################################

  def base_storage_extents_long
    dh = {}
    getLeafNodes(HostToBaseSe, self, dh)
    dh.values.compact.uniq.delete_if { |ae| !ae.kinda?("CIM_StorageExtent") }
  end

  def base_storage_extents
    getAssociators(HostToBseShortcut)
  end

  def base_storage_extents_size
    getAssociationSize(HostToBseShortcut)
  end

end
