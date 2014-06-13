require 'cim_profile_defs'

class CimLogicalDisk < CimStorageExtent
  virtual_column    :element_name,              :type => :string
  virtual_column    :name,                  :type => :string
  virtual_column    :data_redundancy,           :type => :integer
  virtual_column    :delta_reservation,           :type => :integer
  virtual_column    :no_single_point_of_failure?,     :type => :boolean
  virtual_column    :is_based_on_underlying_redundancy?,  :type => :boolean

  virtual_column    :base_storage_extents_size,       :type => :integer
  virtual_column    :file_shares_size,            :type => :integer
  virtual_column    :cim_datastores_size,         :type => :integer
  virtual_column    :storages_size,             :type => :integer
  virtual_column    :cim_virtual_disks_size,        :type => :integer
  virtual_column    :virtual_disks_size,          :type => :integer
  virtual_column    :cim_vms_size,              :type => :integer
  virtual_column    :vms_size,                :type => :integer
  virtual_column    :cim_hosts_size,            :type => :integer
  virtual_column    :hosts_size,              :type => :integer

  virtual_has_many  :base_storage_extents,          :class_name => 'CimStorageExtent'

  virtual_belongs_to  :file_system,             :class_name => 'SniaLocalFileSystem'
  virtual_has_many  :file_shares,             :class_name => 'SniaFileShare'
  virtual_has_many  :cim_datastores,            :class_name => 'MiqCimDatastore'
  virtual_has_many  :storages,                :class_name => 'Storage'
  virtual_has_many  :cim_virtual_disks,           :class_name => 'MiqCimVirtualDisk'
  virtual_has_many  :virtual_disks,             :class_name => 'MiqCimVirtualDisk'
  virtual_has_many  :cim_vms,               :class_name => 'MiqCimVirtualMachine'
  virtual_has_many  :vms,                 :class_name => 'VmOrTemplate'
  virtual_has_many  :hosts,                 :class_name => 'Host'
  virtual_belongs_to  :storage_system,            :class_name => 'CimComputerSystem'

  MODEL_SUBCLASSES  = [ 'OntapLogicalDisk' ]

  LogicalDiskToBaseSe         = CimProfiles.storage_extent_to_base_storage_extent
  LogicalDiskToFileShare        = CimProfiles.logical_disk_to_file_share
  LogicalDiskToDatastores       = CimProfiles.logical_disk_to_datastore
  LogicalDiskToVirtualDisk      = CimProfiles.logical_disk_to_virtual_disk
  LogicalDiskToVm           = CimProfiles.logical_disk_to_virtual_machine
  LogicalDiskToHost         = CimProfiles.logical_disk_to_host
  LogicalDiskToLfs          = CimAssociations.CIM_StorageExtent_TO_SNIA_LocalFileSystem
  LogicalDiskToStorageSystem      = CimAssociations.CIM_LogicalDisk_TO_CIM_ComputerSystem

  LogicalDiskToBseShortcut      = CimAssociations.CIM_LogicalDisk_TO_CIM_StorageExtent_SC
  LogicalDiskToFileShareShortcut    = CimAssociations.CIM_LogicalDisk_TO_SNIA_FileShare_SC
  LogicalDiskToDatastoreShortcut    = CimAssociations.CIM_LogicalDisk_TO_MIQ_CimDatastore_SC
  LogicalDiskToVirtualDiskShortcut  = CimAssociations.CIM_LogicalDisk_TO_MIQ_CimVirtualDisk_SC
  LogicalDiskToVmShortcut       = CimAssociations.CIM_LogicalDisk_TO_MIQ_CimVirtualMachine_SC
  LogicalDiskToHostShortcut     = CimAssociations.CIM_LogicalDisk_TO_MIQ_CimHostSystem_SC

  SHORTCUT_DEFS = {
    :base_storage_extents_long  => LogicalDiskToBseShortcut,
    :file_shares_long     => LogicalDiskToFileShareShortcut,
    :cim_datastores_long    => LogicalDiskToDatastoreShortcut,
    :cim_virtual_disks_long   => LogicalDiskToVirtualDiskShortcut,
    :cim_vms_long       => LogicalDiskToVmShortcut,
    :cim_hosts_long       => LogicalDiskToHostShortcut
  }

  #####################################################
  # Base Storage Extent (primordial disk) associations
  #####################################################

  def base_storage_extents_long
    dh = {}
    getLeafNodes(LogicalDiskToBaseSe, self, dh)
    dh.values.compact.uniq
  end

  def base_storage_extents
    getAssociators(LogicalDiskToBseShortcut)
  end

  def base_storage_extents_size
    getAssociationSize(LogicalDiskToBseShortcut)
  end

  ##########################
  # Filesystem associations
  ##########################

  #
  # No shortcut needed, direct association.
  #
  def local_file_system
    getAssociators(LogicalDiskToLfs).first
  end

  # Old name - should change
  def file_system
    local_file_system
  end

  ##########################
  # File Share associations
  ##########################

  def file_shares_long
    dh = {}
    getLeafNodes(LogicalDiskToFileShare, self, dh)
    dh.values.compact.uniq
  end

  def file_shares
    getAssociators(LogicalDiskToFileShareShortcut)
  end

  def file_shares_size
    getAssociationSize(LogicalDiskToFileShareShortcut)
  end

  #########################
  # Datastore associations
  #########################

  def cim_datastores_long
    dh = {}
    getLeafNodes(LogicalDiskToDatastores, self, dh)
    dh.values.compact.uniq.delete_if { |ae| ae.class_name != "MIQ_CimDatastore" }
  end

  def cim_datastores
    getAssociators(LogicalDiskToDatastoreShortcut)
  end

  def cim_datastores_size
    getAssociationSize(LogicalDiskToDatastoreShortcut)
  end

  def storages
    getAssociatedVmdbObjs(LogicalDiskToDatastoreShortcut)
  end

  def storages_size
    getAssociationSize(LogicalDiskToDatastoreShortcut)
  end

  ############################
  # Virtual disk associations
  ############################

  def cim_virtual_disks_long
    dh = {}
    getLeafNodes(LogicalDiskToVirtualDisk, self, dh)
    dh.values.compact.uniq.delete_if { |ae| ae.class_name != "MIQ_CimVirtualDisk" }
  end

  def cim_virtual_disks
    getAssociators(LogicalDiskToVirtualDiskShortcut)
  end

  def cim_virtual_disks_size
    getAssociationSize(LogicalDiskToVirtualDiskShortcut)
  end

  def virtual_disks
    getAssociatedVmdbObjs(LogicalDiskToVirtualDiskShortcut)
  end

  def virtual_disks_size
    getAssociationSize(LogicalDiskToVirtualDiskShortcut)
  end

  ##################
  # VM associations
  ##################

  def cim_vms_long
    dh = {}
    getLeafNodes(LogicalDiskToVm, self, dh)
    dh.values.compact.uniq.delete_if { |ae| ae.class_name != "MIQ_CimVirtualMachine" }
  end

  def cim_vms
    getAssociators(LogicalDiskToVmShortcut)
  end

  def cim_vms_size
    getAssociationSize(LogicalDiskToVmShortcut)
  end

  def vms
    getAssociatedVmdbObjs(LogicalDiskToVmShortcut)
  end

  def vms_size
    getAssociationSize(LogicalDiskToVmShortcut)
  end

  ####################
  # Host associations
  ####################

  def cim_hosts_long
    dh = {}
    getLeafNodes(LogicalDiskToHost, self, dh)
    dh.values.compact.uniq.delete_if { |ae| ae.class_name != "MIQ_CimHostSystem" }
  end

  def cim_hosts
    getAssociators(LogicalDiskToHostShortcut)
  end

  def cim_hosts_size
    getAssociationSize(LogicalDiskToHostShortcut)
  end

  def hosts
    getAssociatedVmdbObjs(LogicalDiskToHostShortcut)
  end

  def hosts_size
    getAssociationSize(LogicalDiskToHostShortcut)
  end

  ##############################
  # Storage system associations
  ##############################

  #
  # No shortcut needed, direct association.
  #
  def storage_system
    getAssociators(LogicalDiskToStorageSystem).first
  end

  ###################
  # End associations
  ###################

  def evm_display_name
    @evmDisplayName ||= begin
      if storage_system.nil?
        name
      else
        storage_system.evm_display_name + ":" + name
      end
    end
  end

  def element_name
    property('ElementName')
  end

  def name
    property('Name')
  end

  def data_redundancy
    property('DataRedundancy')
  end

  def delta_reservation
    property('DeltaReservation')
  end

  def no_single_point_of_failure?
    property('NoSinglePointOfFailure')
  end

  def is_based_on_underlying_redundancy?
    property('IsBasedOnUnderlyingRedundancy')
  end

end

# Preload any subclasses of this class, so that they will be part of the
# conditions that are generated on queries against this class.
CimLogicalDisk::MODEL_SUBCLASSES.each { |sc| require_dependency File.join(Rails.root, 'app', 'models', sc.underscore + '.rb')}
