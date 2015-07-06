class OntapStorageSystem < CimComputerSystem
  virtual_has_many  :ontap_flex_vols,   :class_name => 'OntapFlexVolExtent'
  virtual_has_many  :ontap_file_shares,   :class_name => "OntapFileShare"
  virtual_has_many  :ontap_storage_volumes, :class_name => "OntapStorageVolume"
  virtual_has_many  :ontap_logical_disks, :class_name => "OntapLogicalDisk"

  StorageSystemToFlexVol  = CimAssociations.ONTAP_StorageSystem_TO_ONTAP_FlexVolExtent

  def ontap_flex_vols
    getAssociators(StorageSystemToFlexVol)
  end

  def ontap_file_shares
    hosted_file_shares
  end

  def ontap_storage_volumes
    storage_volumes
  end

  def ontap_logical_disks
    logical_disks
  end
end
