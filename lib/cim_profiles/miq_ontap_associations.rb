require 'cim_profile_types'

CimAssociations.update do
  # ONTAP_StorageSystem_TO_ONTAP_FlexVolExtent
  # ONTAP_FlexVolExtent_TO_ONTAP_StorageSystem
  add do
    assoc_class   'CIM_SystemDevice'
    from_class    'ONTAP_StorageSystem'
    result_class  'ONTAP_FlexVolExtent'
    role      'GroupComponent'
    result_role   'PartComponent'
  end

  # ONTAP_FileShare_TO_ONTAP_FlexVolExtent
  # ONTAP_FlexVolExtent_TO_ONTAP_FileShare
  add do
    assoc_class   'MIQ_ONTAP_FileShareFlexVol'
    from_class    'ONTAP_FileShare'
    result_class  'ONTAP_FlexVolExtent'
    role      'FileShare'
    result_role   'FlexVol'
  end

  #
  # The following associations are only used to query the database.
  # They return type specific associations based on the general
  # definitions in the database.
  #

  # ONTAP_StorageSystem_TO_ONTAP_FileShare
  # ONTAP_FileShare_TO_ONTAP_StorageSystem
  add do
    assoc_class   'CIM_HostedShare'
    from_class    'ONTAP_StorageSystem'
    result_class  'ONTAP_FileShare'
    role      'Antecedent'
    result_role   'Dependent'
  end

  # ONTAP_StorageSystem_TO_ONTAP_StorageVolume
  # ONTAP_StorageVolume_TO_ONTAP_StorageSystem
  add do
    assoc_class   'CIM_SystemDevice'
    from_class    'ONTAP_StorageSystem'
    result_class  'ONTAP_StorageVolume'
    role      'GroupComponent'
    result_role   'PartComponent'
  end

  # ONTAP_StorageSystem_TO_ONTAP_LogicalDisk
  # ONTAP_LogicalDisk_TO_ONTAP_StorageSystem
  add do
    assoc_class   'CIM_SystemDevice'
    from_class    'ONTAP_StorageSystem'
    result_class  'ONTAP_LogicalDisk'
    role      'GroupComponent'
    result_role   'PartComponent'
  end

  # ONTAP_FlexVolExtent_TO_ONTAP_StorageVolume
  # ONTAP_StorageVolume_TO_ONTAP_FlexVolExtent
  add do
    assoc_class   'CIM_BasedOn'
    from_class    'ONTAP_FlexVolExtent'
    result_class  'ONTAP_StorageVolume'
    role      'Antecedent'
    result_role   'Dependent'
  end

  # ONTAP_FlexVolExtent_TO_ONTAP_LogicalDisk
  # ONTAP_LogicalDisk_TO_ONTAP_FlexVolExtent
  add do
    assoc_class   'CIM_BasedOn'
    from_class    'ONTAP_FlexVolExtent'
    result_class  'ONTAP_LogicalDisk'
    role      'Antecedent'
    result_role   'Dependent'
  end

  # ONTAP_FlexVolExtent_TO_ONTAP_ConcreteExtent
  # ONTAP_ConcreteExtent_TO_ONTAP_FlexVolExtent
  add do
    assoc_class   'CIM_BasedOn'
    from_class    'ONTAP_FlexVolExtent'
    result_class  'ONTAP_ConcreteExtent'
    role      'Dependent'
    result_role   'Antecedent'
  end

  # ONTAP_ConcreteExtent_TO_ONTAP_PlexExtent
  # ONTAP_PlexExtent_TO_ONTAP_ConcreteExtent
  add do
    assoc_class   'CIM_BasedOn'
    from_class    'ONTAP_ConcreteExtent'
    result_class  'ONTAP_PlexExtent'
    role      'Dependent'
    result_role   'Antecedent'
  end

  # ONTAP_PlexExtent_TO_ONTAP_RAIDGroupExtent
  # ONTAP_RAIDGroupExtent_TO_ONTAP_PlexExtent
  add do
    assoc_class   'CIM_BasedOn'
    from_class    'ONTAP_PlexExtent'
    result_class  'ONTAP_RAIDGroupExtent'
    role      'Dependent'
    result_role   'Antecedent'
  end

  # ONTAP_RAIDGroupExtent_TO_ONTAP_DiskExtent
  # ONTAP_DiskExtent_TO_ONTAP_RAIDGroupExtent
  add do
    assoc_class   'CIM_BasedOn'
    from_class    'ONTAP_RAIDGroupExtent'
    result_class  'ONTAP_DiskExtent'
    role      'Dependent'
    result_role   'Antecedent'
  end
end
