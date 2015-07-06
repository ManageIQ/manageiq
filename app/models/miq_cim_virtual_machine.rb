require 'cim_profile_defs'

class MiqCimVirtualMachine < MiqCimInstance
  include ReportableMixin

  virtual_has_many  :cim_virtual_disks,     :class_name => 'MiqCimVirtualDisk'
  virtual_has_many  :cim_datastores,      :class_name => 'MiqCimDatastore'
  virtual_has_many  :storages,          :class_name => 'Storage'
  virtual_has_many  :datastore_backing,     :class_name => 'MiqCimInstance'
  virtual_has_many  :storage_systems,     :class_name => 'CimComputerSystem'
  virtual_has_many  :file_shares,       :class_name => 'SniaFileShare'
  virtual_has_many  :storage_volumes,     :class_name => 'CimStorageVolume'
  virtual_has_many  :file_systems,        :class_name => 'SniaLocalFileSystem'
  virtual_has_many  :logical_disks,       :class_name => 'CimLogicalDisk'
  virtual_has_many  :base_storage_extents,    :class_name => 'CimStorageExtent'

  virtual_has_many  :hosts,           :class_name => 'Host'

  virtual_column    :base_storage_extents_size, :type => :integer
  virtual_column    :file_shares_size,      :type => :integer
  virtual_column    :cim_datastores_size,   :type => :integer
  virtual_column    :storages_size,       :type => :integer
  virtual_column    :cim_virtual_disks_size,  :type => :integer
  virtual_column    :cim_hosts_size,      :type => :integer
  virtual_column    :hosts_size,        :type => :integer
  virtual_column    :logical_disks_size,    :type => :integer

  VirtualMachineToLfs           = CimProfiles.virtual_machine_to_filesystem
  VirtualMachineToBaseSe          = CimProfiles.virtual_machine_to_base_storage_extent
  VirtualMachineToVirtualDisk       = CimAssociations.MIQ_CimVirtualMachine_TO_MIQ_CimVirtualDisk
  VirtualMachineToHost          = CimAssociations.MIQ_CimVirtualMachine_TO_MIQ_CimHostSystem

  VirtualMachineToDatastoreShortcut   = CimAssociations.MIQ_VirtualMachine_TO_MIQ_CimDatastore_SC
  VirtualMachineToLfsShortcut       = CimAssociations.MIQ_VirtualMachine_TO_SNIA_LocalFileSystem_SC
  VirtualMachineToFileShareShortcut   = CimAssociations.MIQ_VirtualMachine_TO_SNIA_FileShare_SC
  VirtualMachineToStorageVolumeShortcut = CimAssociations.MIQ_VirtualMachine_TO_MIQ_CimStorageVolume_SC
  VirtualMachineToCcsShortcut       = CimAssociations.MIQ_VirtualMachine_TO_CIM_ComputerSystem_SC
  VirtualMachineToLogicalDiskShortcut   = CimAssociations.MIQ_VirtualMachine_TO_CIM_LogicalDisk_SC
  VirtualMachineToBaseSeShortcut      = CimAssociations.MIQ_VirtualMachine_TO_CIM_StorageExtent_SC

  SHORTCUT_DEFS = {
    :local_file_systems_long  => VirtualMachineToLfsShortcut,
    :base_storage_extents_long  => VirtualMachineToBaseSeShortcut
  }

  ############################
  # Virtual disk associations
  ############################

  #
  # No shortcut needed, direct association.
  #
  def cim_virtual_disks
    getAssociators(VirtualMachineToVirtualDisk)
  end

  def cim_virtual_disks_size
    getAssociationSize(VirtualMachineToVirtualDisk)
  end

  #########################
  # Datastore associations
  #########################

  #
  # Association created by MiqCimDatastore class.
  #
  def cim_datastores
    getAssociators(VirtualMachineToDatastoreShortcut)
  end

  def cim_datastores_size
    getAssociationSize(VirtualMachineToDatastoreShortcut)
  end

  def storages
    getAssociatedVmdbObjs(VirtualMachineToDatastoreShortcut)
  end

  def storages_size
    getAssociationSize(VirtualMachineToDatastoreShortcut)
  end

  ##########################
  # File Share associations
  ##########################

  #
  # Association created by SniaFileShare class.
  #
  def file_shares
    getAssociators(VirtualMachineToFileShareShortcut)
  end

  def file_shares_size
    getAssociationSize(VirtualMachineToFileShareShortcut)
  end

  ##############################
  # Storage system associations
  ##############################

  #
  # Association created by CimStorageVolume class.
  #
  def storage_volumes
    getAssociators(VirtualMachineToStorageVolumeShortcut)
  end

  def storage_volumes_size
    getAssociationSize(VirtualMachineToStorageVolumeShortcut)
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
    getAssociators(VirtualMachineToCcsShortcut)
  end

  def storage_systems_size
    getAssociationSize(VirtualMachineToCcsShortcut)
  end

  ############################
  # Logical Disk associations
  ############################

  #
  # Association created by CimLogicalDisk class.
  #
  def logical_disks
    getAssociators(VirtualMachineToLogicalDiskShortcut)
  end

  def logical_disks_size
    getAssociationSize(VirtualMachineToLogicalDiskShortcut)
  end

  ##########################
  # Filesystem associations
  ##########################

  def local_file_systems_long
    dh = {}
    getLeafNodes(VirtualMachineToLfs, self, dh)
    dh.values.compact.uniq.delete_if { |ae| !ae.kinda?("SNIA_LocalFileSystem") }
  end

  def local_file_systems
    getAssociators(VirtualMachineToLfsShortcut)
  end

  def local_file_systems_size
    getAssociationSize(VirtualMachineToLfsShortcut)
  end

  # Old name - should change
  def file_systems
    local_file_systems
  end

  #####################################################
  # Base Storage Extent (primordial disk) associations
  #####################################################

  def base_storage_extents_long
    dh = {}
    getLeafNodes(VirtualMachineToBaseSe, self, dh)
    dh.values.compact.uniq.delete_if { |ae| !ae.kinda?("CIM_StorageExtent") }
  end

  def base_storage_extents
    getAssociators(VirtualMachineToBaseSeShortcut)
  end

  def base_storage_extents_size
    getAssociationSize(VirtualMachineToBaseSeShortcut)
  end

  ####################
  # Host associations
  ####################

  #
  # No shortcut needed, direct association.
  #
  def cim_hosts
    getAssociators(VirtualMachineToHost)
  end

  def cim_hosts_size
    getAssociationSize(VirtualMachineToHost)
  end

  def hosts
    getAssociatedVmdbObjs(VirtualMachineToHost)
  end

  def hosts_size
    getAssociationSize(VirtualMachineToHost)
  end

end
