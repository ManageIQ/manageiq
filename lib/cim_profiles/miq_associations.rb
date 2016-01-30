require 'cim_profile_types'

CimAssociations.update do
  # MIQ_CimHostSystem_TO_MIQ_CimDatastore
  # MIQ_CimDatastore_TO_MIQ_CimHostSystem
  add do
    assoc_class   'MIQ_HostDatastore'
    from_class    'MIQ_CimHostSystem'
    result_class  'MIQ_CimDatastore'
    role      'Antecedent'
    result_role   'Dependent'
  end

  # MIQ_CimVirtualMachine_TO_MIQ_CimHostSystem
  # MIQ_CimHostSystem_TO_MIQ_CimVirtualMachine
  add do
    assoc_class   'MIQ_VmHost'
    from_class    'MIQ_CimVirtualMachine'
    result_class  'MIQ_CimHostSystem'
    role      'Antecedent'
    result_role   'Dependent'
  end

  # MIQ_CimVirtualMachine_TO_MIQ_CimVirtualDisk
  # MIQ_CimVirtualDisk_TO_MIQ_CimVirtualMachine
  add do
    assoc_class   'MIQ_VmVirtualDisk'
    from_class    'MIQ_CimVirtualMachine'
    result_class  'MIQ_CimVirtualDisk'
    role      'Antecedent'
    result_role   'Dependent'
  end

  # MIQ_CimVirtualDisk_TO_MIQ_CimDatastore
  # MIQ_CimDatastore_TO_MIQ_CimVirtualDisk
  add do
    assoc_class   'MIQ_VirtualDiskDatastore'
    from_class    'MIQ_CimVirtualDisk'
    result_class  'MIQ_CimDatastore'
    role      'Antecedent'
    result_role   'Dependent'
  end

  # MIQ_CimDatastore_TO_CIM_FileShare
  # CIM_FileShare_TO_MIQ_CimDatastore
  add do
    assoc_class   'MIQ_DatastoreBacking'
    from_class    'MIQ_CimDatastore'
    result_class  'CIM_FileShare'
    role      'Antecedent'
    result_role   'Dependent'
  end

  # MIQ_CimDatastore_TO_CIM_StorageVolume
  # CIM_StorageVolume_TO_MIQ_CimDatastore
  add do
    assoc_class   'MIQ_DatastoreBacking'
    from_class    'MIQ_CimDatastore'
    result_class  'CIM_StorageVolume'
    role      'Antecedent'
    result_role   'Dependent'
  end

  # MIQ_CimDatastore_TO_CIM_EnabledLogicalElement
  # CIM_EnabledLogicalElement_TO_MIQ_CimDatastore
  add do
    assoc_class   'MIQ_DatastoreBacking'
    from_class    'MIQ_CimDatastore'
    result_class  'CIM_EnabledLogicalElement'
    role      'Antecedent'
    result_role   'Dependent'
  end
end # CimAssociations.update
