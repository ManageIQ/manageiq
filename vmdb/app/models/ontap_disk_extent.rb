require 'cim_profile_defs'

class OntapDiskExtent < CimStorageExtent
  virtual_belongs_to  :ontap_raid_group,  :class_name => 'OntapRaidGroupExtent'

  DiskToRaidGroup = CimAssociations.ONTAP_DiskExtent_TO_ONTAP_RAIDGroupExtent

  def ontap_raid_group
    getAssociators(DiskToRaidGroup).first
  end
end
