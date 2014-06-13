require 'cim_profile_types'

CimAssociations.update {

  # CIM_ComputerSystem_TO_CIM_FileShare
  # CIM_FileShare_TO_CIM_ComputerSystem
  add {
    assoc_class   'CIM_HostedShare'
    from_class    'CIM_ComputerSystem'
    result_class  'CIM_FileShare'
    role      'Antecedent'
    result_role   'Dependent'
  }

  # CIM_ComputerSystem_TO_CIM_LogicalDisk
  # CIM_LogicalDisk_TO_CIM_ComputerSystem
  add {
    assoc_class   'CIM_SystemDevice'
    from_class    'CIM_ComputerSystem'
    result_class  'CIM_LogicalDisk'
    role      'GroupComponent'
    result_role   'PartComponent'
  }

  # CIM_ComputerSystem_TO_CIM_StorageVolume
  # CIM_StorageVolume_TO_CIM_ComputerSystem
  add {
    assoc_class   'CIM_SystemDevice'
    from_class    'CIM_ComputerSystem'
    result_class  'CIM_StorageVolume'
    role      'GroupComponent'
    result_role   'PartComponent'
  }

  # CIM_ComputerSystem_TO_CIM_StorageExtent
  # CIM_StorageExtent_TO_CIM_ComputerSystem
  add {
    assoc_class   'CIM_SystemDevice'
    from_class    'CIM_ComputerSystem'
    result_class  'CIM_StorageExtent'
    role      'GroupComponent'
    result_role   'PartComponent'
  }

  # CIM_ComputerSystem_TO_CIM_IPProtocolEndpoint
  # CIM_IPProtocolEndpoint_TO_CIM_ComputerSystem
  add {
    assoc_class   'CIM_HostedAccessPoint'
    from_class    'CIM_ComputerSystem'
    result_class  'CIM_IPProtocolEndpoint'
    role      'Antecedent'
    result_role   'Dependent'
  }

  # CIM_FileShare_TO_SNIA_LocalFileSystem
  # SNIA_LocalFileSystem_TO_CIM_FileShare
  add {
    assoc_class   'SNIA_SharedElement'
    from_class    'CIM_FileShare'
    result_class  'SNIA_LocalFileSystem'
    role      'SameElement'
    result_role   'SystemElement'
  }

  # CIM_FileShare_TO_CIM_ProtocolEndpoint
  # CIM_ProtocolEndpoint_TO_CIM_FileShare
  add {
    assoc_class   'CIM_SAPAvailableForElement'
    from_class    'CIM_FileShare'
    result_class  'CIM_ProtocolEndpoint'
    role      'ManagedElement'
    result_role   'AvailableSAP'
  }

  # CIM_ProtocolEndpoint_TO_CIM_NetworkPort
  # CIM_NetworkPort_TO_CIM_ProtocolEndpoint
  add {
    assoc_class   'CIM_DeviceSAPImplementation'
    from_class    'CIM_ProtocolEndpoint'
    result_class  'CIM_NetworkPort'
    role      'Dependent'
    result_role   'Antecedent'
  }

  # CIM_NetworkPort_TO_CIM_IPProtocolEndpoint
  # CIM_IPProtocolEndpoint_TO_CIM_NetworkPort
  add {
    assoc_class   'CIM_DeviceSAPImplementation'
    from_class    'CIM_NetworkPort'
    result_class  'CIM_IPProtocolEndpoint'
    role      'Antecedent'
    result_role   'Dependent'
  }

  # SNIA_LocalFileSystem_TO_CIM_StorageExtent
  # CIM_StorageExtent_TO_SNIA_LocalFileSystem
  add {
    assoc_class   'CIM_ResidesOnExtent'
    from_class    'SNIA_LocalFileSystem'
    result_class  'CIM_StorageExtent'
    role      'Dependent'
    result_role   'Antecedent'
  }

  CIM_StorageExtent_TO_CIM_StorageExtent_down {
    assoc_class   'CIM_BasedOn'
    from_class    'CIM_StorageExtent'
    result_class  'CIM_StorageExtent'
    role      'Dependent'
    result_role   'Antecedent'
  }

  CIM_StorageExtent_TO_CIM_StorageExtent_up self[:CIM_StorageExtent_TO_CIM_StorageExtent_down].reverse

  # CIM_StorageExtent_TO_CIM_StorageSetting
  # CIM_StorageSetting_TO_CIM_StorageExtent
  add {
    assoc_class   'CIM_ElementSettingData'
    from_class    'CIM_StorageExtent'
    result_class  'CIM_StorageSetting'
    role      'ManagedElement'
    result_role   'SettingData'
  }

} # CimAssociations.update
