class OntapStorageVolume < CimStorageVolume
  virtual_belongs_to  :ontap_flex_vol,  :class_name => 'OntapFlexVolExtent'

  StorageVolumeToFlexVol  = CimAssociations.ONTAP_StorageVolume_TO_ONTAP_FlexVolExtent

  def ontap_flex_vol
    getAssociators(StorageVolumeToFlexVol).first
  end

  def correlatable_id
    super.split(" ").last
  end

end
