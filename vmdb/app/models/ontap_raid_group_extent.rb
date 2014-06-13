require 'cim_profile_defs'

class OntapRaidGroupExtent < CimStorageExtent
  virtual_belongs_to  :ontap_plex,      :class_name => 'OntapPlexExtent'
  virtual_has_many  :ontap_disk_extents,  :class_name => 'OntapDiskExtent'

  RaidGroupToPlex   = CimAssociations.ONTAP_RAIDGroupExtent_TO_ONTAP_PlexExtent
  RaidGroupToDisks  = CimAssociations.ONTAP_RAIDGroupExtent_TO_ONTAP_DiskExtent

  def ontap_plex
    getAssociators(RaidGroupToPlex).first
  end

  def ontap_disk_extents
    getAssociators(RaidGroupToDisks)
  end
end
