require 'cim_profile_defs'

class OntapPlexExtent < CimStorageExtent
  virtual_belongs_to  :ontap_concrete_extent,   :class_name => 'OntapConcreteExtent'
  virtual_belongs_to  :ontap_aggregate,     :class_name => 'OntapConcreteExtent'
  virtual_has_many  :ontap_raid_groups,     :class_name => 'OntapRaidGroupExtent'

  PlexToConcreteExtent  = CimAssociations.ONTAP_PlexExtent_TO_ONTAP_ConcreteExtent
  PlexToRaidGroups    = CimAssociations.ONTAP_PlexExtent_TO_ONTAP_RAIDGroupExtent

  def ontap_concrete_extent
    getAssociators(PlexToConcreteExtent).first
  end

  def ontap_aggregate
    ontap_concrete_extent
  end

  def ontap_raid_groups
    getAssociators(PlexToRaidGroups)
  end
end
