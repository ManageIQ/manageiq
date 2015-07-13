require 'cim_profile_defs'

class OntapConcreteExtent < CimStorageExtent
  virtual_has_many  :ontap_plexes,    :class_name => 'OntapPlexExtent'
  virtual_has_one   :ontap_flex_vol,  :class_name => 'OntapFlexVolExtent'

  ConcreteExtentToPlex  = CimAssociations.ONTAP_ConcreteExtent_TO_ONTAP_PlexExtent
  ConcreteExtentToFlexVol = CimAssociations.ONTAP_ConcreteExtent_TO_ONTAP_FlexVolExtent

  def ontap_plexes
    getAssociators(ConcreteExtentToPlex)
  end

  def ontap_flex_vol
    getAssociators(ConcreteExtentToFlexVol).first
  end
end
