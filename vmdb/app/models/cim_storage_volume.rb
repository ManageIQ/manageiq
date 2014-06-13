require 'cim_profile_defs'

class CimStorageVolume < CimStorageExtent
  virtual_column    :element_name,              :type => :string
  virtual_column    :name,                  :type => :string
  virtual_column    :data_redundancy,           :type => :integer
  virtual_column    :delta_reservation,           :type => :integer
  virtual_column    :no_single_point_of_failure?,     :type => :boolean
  virtual_column    :is_based_on_underlying_redundancy?,  :type => :boolean

  virtual_column    :base_storage_extents_size,       :type => :integer
  virtual_column    :cim_datastores_size,         :type => :integer
  virtual_column    :storages_size,             :type => :integer
  virtual_column    :cim_virtual_disks_size,        :type => :integer
  virtual_column    :cim_vms_size,              :type => :integer
  virtual_column    :vms_size,                :type => :integer
  virtual_column    :cim_hosts_size,            :type => :integer
  virtual_column    :hosts_size,              :type => :integer

  virtual_has_many  :base_storage_extents,          :class_name => 'CimStorageExtent'

  virtual_has_many  :cim_datastores,            :class_name => 'MiqCimDatastore'
  virtual_has_many  :storages,                :class_name => 'Storage'
  virtual_has_many  :cim_virtual_disks,           :class_name => 'MiqCimVirtualDisk'
  virtual_has_many  :cim_vms,               :class_name => 'MiqCimVirtualMachine'
  virtual_has_many  :vms,                 :class_name => 'VmOrTemplate'
  virtual_has_many  :hosts,                 :class_name => 'Host'
  virtual_belongs_to  :storage_system,            :class_name => 'CimComputerSystem'

  MODEL_SUBCLASSES  = [ 'OntapStorageVolume' ]

  StorageVolumeToBaseSe       = CimProfiles.storage_extent_to_base_storage_extent
  StorageVolumeToVirtualDisk      = CimProfiles.storage_volume_to_virtual_disk
  StorageVolumeToVm         = CimProfiles.storage_volume_to_virtual_machine
  StorageVolumeToHost         = CimProfiles.storage_volume_to_host
  StorageVolumeToDatastores     = CimAssociations.CIM_StorageVolume_TO_MIQ_CimDatastore
  StorageVolumeToStorageSystem    = CimAssociations.CIM_StorageVolume_TO_CIM_ComputerSystem

  StorageVolumeToBseShortcut      = CimAssociations.CIM_StorageVolume_TO_CIM_StorageExtent_SC
  StorageVolumeToVirtualDiskShortcut  = CimAssociations.CIM_StorageVolume_TO_MIQ_CimVirtualDisk_SC
  StorageVolumeToVmShortcut     = CimAssociations.CIM_StorageVolume_TO_MIQ_CimVirtualMachine_SC
  StorageVolumeToHostShortcut     = CimAssociations.CIM_StorageVolume_TO_MIQ_CimHostSystem_SC

  SHORTCUT_DEFS = {
    :base_storage_extents_long  => StorageVolumeToBseShortcut,
    :cim_virtual_disks_long   => StorageVolumeToVirtualDiskShortcut,
    :cim_vms_long       => StorageVolumeToVmShortcut,
    :cim_hosts_long       => StorageVolumeToHostShortcut
  }

  #####################################################
  # Base Storage Extent (primordial disk) associations
  #####################################################

  def base_storage_extents_long
    dh = {}
    getLeafNodes(StorageVolumeToBaseSe, self, dh)
    dh.values.compact.uniq
  end

  def base_storage_extents
    getAssociators(StorageVolumeToBseShortcut)
  end

  def base_storage_extents_size
    getAssociationSize(StorageVolumeToBseShortcut)
  end

  #########################
  # Datastore associations
  #########################

  def cim_datastores
    getAssociators(StorageVolumeToDatastores)
  end

  def cim_datastores_size
    getAssociationSize(StorageVolumeToDatastores)
  end

  def storages
    getAssociatedVmdbObjs(StorageVolumeToDatastores)
  end

  def storages_size
    getAssociationSize(StorageVolumeToDatastores)
  end

  ############################
  # Virtual disk associations
  ############################

  def cim_virtual_disks_long
    dh = {}
    getLeafNodes(StorageVolumeToVirtualDisk, self, dh)
    dh.values.compact.uniq.delete_if { |ae| ae.class_name != "MIQ_CimVirtualDisk" }
  end

  def cim_virtual_disks
    getAssociators(StorageVolumeToVirtualDiskShortcut)
  end

  def cim_virtual_disks_size
    getAssociationSize(StorageVolumeToVirtualDiskShortcut)
  end

  ##################
  # VM associations
  ##################

  def cim_vms_long
    dh = {}
    getLeafNodes(StorageVolumeToVm, self, dh)
    dh.values.compact.uniq.delete_if { |ae| ae.class_name != "MIQ_CimVirtualMachine" }
  end

  def cim_vms
    getAssociators(StorageVolumeToVmShortcut)
  end

  def cim_vms_size
    getAssociationSize(StorageVolumeToVmShortcut)
  end

  def vms
    getAssociatedVmdbObjs(StorageVolumeToVmShortcut)
  end

  def vms_size
    getAssociationSize(StorageVolumeToVmShortcut)
  end

  ####################
  # Host associations
  ####################

  def cim_hosts_long
    dh = {}
    getLeafNodes(StorageVolumeToHost, self, dh)
    dh.values.compact.uniq.delete_if { |ae| ae.class_name != "MIQ_CimHostSystem" }
  end

  def cim_hosts
    getAssociators(StorageVolumeToHostShortcut)
  end

  def cim_hosts_size
    getAssociationSize(StorageVolumeToHostShortcut)
  end

  def hosts
    getAssociatedVmdbObjs(StorageVolumeToHostShortcut)
  end

  def hosts_size
    getAssociationSize(StorageVolumeToHostShortcut)
  end

  ##############################
  # Storage system associations
  ##############################

  #
  # No shortcut needed, direct association.
  #
  def storage_system
    getAssociators(StorageVolumeToStorageSystem).first
  end

  ###################
  # End associations
  ###################

  def evm_display_name
    @evmDisplayName ||= begin
      if storage_system.nil?
        device_id
      else
        storage_system.evm_display_name + ":" + device_id
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

  def vm_count
    vms.count
  end

  def host_count
    hosts.count
  end

  def storage_count
    storages.count
  end

  def correlatable_id
    self.name
  end

end

# Preload any subclasses of this class, so that they will be part of the
# conditions that are generated on queries against this class.
CimStorageVolume::MODEL_SUBCLASSES.each { |sc| require_dependency File.join(Rails.root, 'app', 'models', sc.underscore + '.rb')}

