require 'cim_profile_defs'
require 'lun_durable_names'

class MiqCimDatastore < MiqCimInstance
  include ReportableMixin

  virtual_has_one   :backing,         :class_name => 'MiqCimInstance'
  virtual_has_one   :file_share,        :class_name => 'SniaFileShare'
  virtual_has_many  :storage_volumes,     :class_name => 'CimStorageVolume'
  virtual_has_many  :storage_systems,     :class_name => 'CimComputerSystem'
  virtual_has_one   :file_system,       :class_name => 'SniaLocalFileSystem'
  virtual_has_one   :logical_disk,        :class_name => 'CimLogicalDisk'
  virtual_has_many  :base_storage_extents,    :class_name => 'CimStorageExtent'

  virtual_has_many  :cim_virtual_disks,     :class_name => 'MiqCimVirtualDisk'
  virtual_has_many  :cim_vms,         :class_name => 'MiqCimVirtualMachine'
  virtual_has_many  :vms,           :class_name => 'Vm'
  virtual_has_many  :hosts,           :class_name => 'Host'

  virtual_column    :base_storage_extents_size, :type => :integer
  virtual_column    :file_share_size,     :type => :integer
  virtual_column    :cim_virtual_disks_size,  :type => :integer
  virtual_column    :cim_vms_size,        :type => :integer
  virtual_column    :vms_size,          :type => :integer
  virtual_column    :cim_hosts_size,      :type => :integer
  virtual_column    :hosts_size,        :type => :integer

  DatastoreToLfs            = CimProfiles.datastore_to_filesystem
  DatastoreToBaseSe         = CimProfiles.datastore_to_base_storage_extent
  DatastoreToVm           = CimProfiles.datastore_to_virtual_machine
  DatastoreToBacking          = CimAssociations.MIQ_CimDatastore_TO_CIM_EnabledLogicalElement
  DatastoreToFileShare        = CimAssociations.MIQ_CimDatastore_TO_CIM_FileShare
  DatastoreToStorageVolume      = CimAssociations.MIQ_CimDatastore_TO_CIM_StorageVolume
  DatastoreToVirtualDisk        = CimAssociations.MIQ_CimDatastore_TO_MIQ_CimVirtualDisk
  DatastoreToHost           = CimAssociations.MIQ_CimDatastore_TO_MIQ_CimHostSystem

  DatastoreToStorageSystemShortcut  = CimAssociations.MIQ_CimDatastore_TO_CIM_ComputerSystem_SC
  DatastoreToLogicalDiskShortcut    = CimAssociations.MIQ_CimDatastore_TO_CIM_LogicalDisk_SC
  DatastoreToLfsShortcut        = CimAssociations.MIQ_CimDatastore_TO_SNIA_LocalFileSystem_SC
  DatastoreToBseShortcut        = CimAssociations.MIQ_CimDatastore_TO_CIM_StorageExtent_SC
  DatastoreToVmShortcut       = CimAssociations.MIQ_CimDatastore_TO_MIQ_CimVirtualMachine_SC


  SHORTCUT_DEFS = {
    :local_file_system_long   => DatastoreToLfsShortcut,
    :base_storage_extents_long  => DatastoreToBseShortcut,
    :cim_vms_long       => DatastoreToVmShortcut
  }

  #############################################
  # Logical disk or Storage volume association
  #############################################

  #
  # No shortcut needed, direct associations.
  #
  def backing
    getAssociators(DatastoreToBacking)
  end

  def backing_size
    getAssociationSize(DatastoreToBacking)
  end

  #
  # No shortcut needed, direct associations.
  #
  def file_share
    getAssociators(DatastoreToFileShare).first
  end

  def file_share_size
    getAssociationSize(DatastoreToFileShare)
  end

  #
  # No shortcut needed, direct associations.
  #
  def storage_volumes
    getAssociators(DatastoreToStorageVolume)
  end

  def storage_volumes_size
    getAssociationSize(DatastoreToStorageVolume)
  end

  ##############################
  # Storage system associations
  ##############################

  #
  # Association created by CimComputerSystem class.
  #
  def storage_systems
    getAssociators(DatastoreToStorageSystemShortcut)
  end

  def storage_systems_size
    getAssociationSize(DatastoreToStorageSystemShortcut)
  end

  ##########################
  # Filesystem associations
  ##########################

  def local_file_system_long
    dh = {}
    getLeafNodes(DatastoreToLfs, self, dh)
    dh.values.compact.uniq.delete_if { |ae| !ae.kinda?("SNIA_LocalFileSystem") }
  end

  def local_file_system
    getAssociators(DatastoreToLfsShortcut).first
  end

  def local_file_system_size
    getAssociationSize(DatastoreToLfsShortcut)
  end

  # Old name - should change
  def file_system
    local_file_system
  end

  ############################
  # Logical Disk associations
  ############################

  #
  # Association created by CimLogicalDisk class.
  #
  def logical_disk
    getAssociators(DatastoreToLogicalDiskShortcut).first
  end

  def logical_disk_size
    getAssociationSize(DatastoreToLogicalDiskShortcut)
  end

  #####################################################
  # Base Storage Extent (primordial disk) associations
  #####################################################

  def base_storage_extents_long
    dh = {}
    getLeafNodes(DatastoreToBaseSe, self, dh)
    dh.values.compact.uniq.delete_if { |ae| !ae.kinda?("CIM_StorageExtent") }
  end

  def base_storage_extents
    getAssociators(DatastoreToBseShortcut)
  end

  def base_storage_extents_size
    getAssociationSize(DatastoreToBseShortcut)
  end

  ############################
  # Virtual disk associations
  ############################

  #
  # No shortcut needed, direct associations.
  #
  def cim_virtual_disks
    getAssociators(DatastoreToVirtualDisk)
  end

  def cim_virtual_disks_size
    getAssociationSize(DatastoreToVirtualDisk)
  end

  ##################
  # VM associations
  ##################

  def cim_vms_long
    dh = {}
    getLeafNodes(DatastoreToVm, self, dh)
    dh.values.compact.uniq.delete_if { |ae| ae.class_name != "MIQ_CimVirtualMachine" }
  end

  def cim_vms
    getAssociators(DatastoreToVmShortcut)
  end

  def cim_vms_size
    getAssociationSize(DatastoreToVmShortcut)
  end

  def vms
    getAssociatedVmdbObjs(DatastoreToVmShortcut)
  end

  def vms_size
    getAssociationSize(DatastoreToVmShortcut)
  end

  ####################
  # Host associations
  ####################

  #
  # No shortcut needed, direct associations.
  #
  def cim_hosts
    getAssociators(DatastoreToHost)
  end

  def cim_hosts_size
    getAssociationSize(DatastoreToHost)
  end

  def hosts
    getAssociatedVmdbObjs(DatastoreToHost)
  end

  def hosts_size
    getAssociationSize(DatastoreToHost)
  end

  def durableNames
    self.type_spec_obj
  end

end
