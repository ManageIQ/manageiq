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

  delegate :base_storage_extents,
           :base_storage_extents_size,
           :cim_datastores,
           :cim_datastores_size,
           :cim_hosts,
           :cim_hosts_size,
           :cim_virtual_disks,
           :cim_virtual_disks_size,
           :cim_vms,
           :cim_vms_size,
           :file_shares,
           :file_shares_size,
           :file_system,
           :hosts,
           :hosts_size,
           :storages,
           :storages_size,
           :virtual_disks,
           :virtual_disks_size,
           :vms,
           :vms_size,
           :to => :ontap_logical_disk
end
