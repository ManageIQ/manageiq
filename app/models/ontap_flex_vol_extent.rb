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

  delegate :base_storage_extents, :to => :ontap_logical_disk

  delegate :base_storage_extents_size, :to => :ontap_logical_disk

  delegate :file_system, :to => :ontap_logical_disk

  delegate :file_shares, :to => :ontap_logical_disk

  delegate :file_shares_size, :to => :ontap_logical_disk

  delegate :cim_datastores, :to => :ontap_logical_disk

  delegate :cim_datastores_size, :to => :ontap_logical_disk

  delegate :storages, :to => :ontap_logical_disk

  delegate :storages_size, :to => :ontap_logical_disk

  delegate :cim_virtual_disks, :to => :ontap_logical_disk

  delegate :cim_virtual_disks_size, :to => :ontap_logical_disk

  delegate :virtual_disks, :to => :ontap_logical_disk

  delegate :virtual_disks_size, :to => :ontap_logical_disk

  delegate :cim_vms, :to => :ontap_logical_disk

  delegate :cim_vms_size, :to => :ontap_logical_disk

  delegate :vms, :to => :ontap_logical_disk

  delegate :vms_size, :to => :ontap_logical_disk

  delegate :cim_hosts, :to => :ontap_logical_disk

  delegate :cim_hosts_size, :to => :ontap_logical_disk

  delegate :hosts, :to => :ontap_logical_disk

  delegate :hosts_size, :to => :ontap_logical_disk
end
