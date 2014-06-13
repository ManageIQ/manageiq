require 'cim_profile_defs'
require 'ontap_logical_disk_mixin'

class OntapFlexVolExtent < CimStorageExtent
  virtual_has_one   :ontap_logical_disk,    :class_name => 'OntapLogicalDisk'
  virtual_has_one   :ontap_storage_volume,    :class_name => 'OntapStorageVolume'
  virtual_belongs_to  :ontap_concrete_extent,   :class_name => 'OntapConcreteExtent'
  virtual_belongs_to  :ontap_aggregate,     :class_name => 'OntapConcreteExtent'
  virtual_belongs_to  :ontap_storage_system,    :class_name => 'OntapStorageSystem'

  virtual_column    :base_storage_extents_size, :type => :integer
  virtual_column    :file_shares_size,      :type => :integer
  virtual_column    :cim_virtual_disks_size,  :type => :integer
  virtual_column    :virtual_disks_size,    :type => :integer

  virtual_has_one   :file_system,       :class_name => 'SniaLocalFileSystem'
  virtual_has_many  :cim_virtual_disks,     :class_name => 'MiqCimVirtualDisk'
  virtual_has_many  :virtual_disks,       :class_name => 'MiqCimVirtualDisk'

  FlexVolToLogicalDisk  = CimAssociations.ONTAP_FlexVolExtent_TO_ONTAP_LogicalDisk
  FlexVolToStorageVolume  = CimAssociations.ONTAP_FlexVolExtent_TO_ONTAP_StorageVolume
  FlexVolToConcreteExtent = CimAssociations.ONTAP_FlexVolExtent_TO_ONTAP_ConcreteExtent
  FlexVolToStorageSystem  = CimAssociations.ONTAP_FlexVolExtent_TO_ONTAP_StorageSystem

  include OntapLogicalDiskMixin

  def ontap_logical_disk
    @ontapLogicalDisk ||= getAssociators(FlexVolToLogicalDisk).first
  end

  def storage_system
    getAssociators(FlexVolToStorageSystem).first
  end

  def ontap_storage_system
    storage_system
  end

  def ontap_storage_volume
    getAssociators(FlexVolToStorageVolume).first
  end

  def ontap_concrete_extent
    getAssociators(FlexVolToConcreteExtent).first
  end

  def ontap_aggregate
    ontap_concrete_extent
  end

  def base_storage_extents
    ontap_logical_disk.base_storage_extents
  end

  def base_storage_extents_size
    ontap_logical_disk.base_storage_extents_size
  end

  def file_system
    ontap_logical_disk.file_system
  end

  def file_shares
    ontap_logical_disk.file_shares
  end

  def file_shares_size
    ontap_logical_disk.file_shares_size
  end

  def cim_datastores
    ontap_logical_disk.cim_datastores
  end

  def cim_datastores_size
    ontap_logical_disk.cim_datastores_size
  end

  def storages
    ontap_logical_disk.storages
  end

  def storages_size
    ontap_logical_disk.storages_size
  end

  def cim_virtual_disks
    ontap_logical_disk.cim_virtual_disks
  end

  def cim_virtual_disks_size
    ontap_logical_disk.cim_virtual_disks_size
  end

  def virtual_disks
    ontap_logical_disk.virtual_disks
  end

  def virtual_disks_size
    ontap_logical_disk.virtual_disks_size
  end

  def cim_vms
    ontap_logical_disk.cim_vms
  end

  def cim_vms_size
    ontap_logical_disk.cim_vms_size
  end

  def vms
    ontap_logical_disk.vms
  end

  def vms_size
    ontap_logical_disk.vms_size
  end

  def cim_hosts
    ontap_logical_disk.cim_hosts
  end

  def cim_hosts_size
    ontap_logical_disk.cim_hosts_size
  end

  def hosts
    ontap_logical_disk.hosts
  end

  def hosts_size
    ontap_logical_disk.hosts_size
  end

end
