require 'cim_profile_types'

CimAssociations.update('_SC') {

  # CIM_ComputerSystem_TO_MIQ_CimVirtualMachine
  # MIQ_CimVirtualMachine_TO_CIM_ComputerSystem
  add {
    assoc_class   'MIQ_StorageSystemVm'
    from_class    'CIM_ComputerSystem'
    result_class  'MIQ_CimVirtualMachine'
    role      'StorageSystem'
    result_role   'VirtualMachine'
  }

  # CIM_ComputerSystem_TO_MIQ_CimHostSystem
  # MIQ_CimHostSystem_TO_CIM_ComputerSystem
  add {
    assoc_class   'MIQ_StorageSystemHost'
    from_class    'CIM_ComputerSystem'
    result_class  'MIQ_CimHostSystem'
    role      'StorageSystem'
    result_role   'Host'
  }

  # CIM_ComputerSystem_TO_MIQ_CimDatastore
  # MIQ_CimDatastore_TO_CIM_ComputerSystem
  add {
    assoc_class   'MIQ_StorageSystemDatastore'
    from_class    'CIM_ComputerSystem'
    result_class  'MIQ_CimDatastore'
    role      'StorageSystem'
    result_role   'Datastore'
  }

  # CIM_ComputerSystem_TO_SNIA_LocalFileSystem
  # SNIA_LocalFileSystem_TO_CIM_ComputerSystem
  add {
    assoc_class   'MIQ_StorageSystemLocalFileSystem'
    from_class    'CIM_ComputerSystem'
    result_class  'SNIA_LocalFileSystem'
    role      'StorageSystem'
    result_role   'LocalFileSystem'
  }

  # CIM_ComputerSystem_TO_CIM_StorageExtent
  # CIM_StorageExtent_TO_CIM_ComputerSystem
  add {
    assoc_class   'MIQ_StorageSystemBaseStorageExtent'
    from_class    'CIM_ComputerSystem'
    result_class  'CIM_StorageExtent'
    role      'StorageSystem'
    result_role   'BaseStorageExtent'
  }

  # CIM_LogicalDisk_TO_CIM_StorageExtent
  # CIM_StorageExtent_TO_CIM_LogicalDisk
  add {
    assoc_class   'MIQ_LogicalDiskBaseStorageExtent'
    from_class    'CIM_LogicalDisk'
    result_class  'CIM_StorageExtent'
    role      'LogicalDisk'
    result_role   'BaseStorageExtent'
  }

  # CIM_LogicalDisk_TO_SNIA_FileShare
  # SNIA_FileShare_TO_CIM_LogicalDisk
  add {
    assoc_class   'MIQ_LogicalDiskFileShare'
    from_class    'CIM_LogicalDisk'
    result_class  'SNIA_FileShare'
    role      'LogicalDisk'
    result_role   'FileShare'
  }

  # CIM_LogicalDisk_TO_MIQ_CimDatastore
  # MIQ_CimDatastore_TO_CIM_LogicalDisk
  add {
    assoc_class   'MIQ_LogicalDiskDatastore'
    from_class    'CIM_LogicalDisk'
    result_class  'MIQ_CimDatastore'
    role      'LogicalDisk'
    result_role   'Datastore'
  }

  # CIM_LogicalDisk_TO_MIQ_CimVirtualDisk
  # MIQ_CimVirtualDisk_TO_CIM_LogicalDisk
  add {
    assoc_class   'MIQ_LogicalDiskVirtualDisk'
    from_class    'CIM_LogicalDisk'
    result_class  'MIQ_CimVirtualDisk'
    role      'LogicalDisk'
    result_role   'VirtualDisk'
  }

  # CIM_LogicalDisk_TO_MIQ_CimVirtualMachine
  # MIQ_CimVirtualMachine_TO_CIM_LogicalDisk
  add {
    assoc_class   'MIQ_LogicalDiskVm'
    from_class    'CIM_LogicalDisk'
    result_class  'MIQ_CimVirtualMachine'
    role      'LogicalDisk'
    result_role   'VirtualMachine'
  }

  # CIM_LogicalDisk_TO_MIQ_CimHostSystem
  # MIQ_CimHostSystem_TO_CIM_LogicalDisk
  add {
    assoc_class   'MIQ_LogicalDiskHost'
    from_class    'CIM_LogicalDisk'
    result_class  'MIQ_CimHostSystem'
    role      'LogicalDisk'
    result_role   'Host'
  }

  # CIM_StorageExtent_TO_MIQ_CimDatastore
  # MIQ_CimDatastore_TO_CIM_StorageExtent
  add {
    assoc_class   'MIQ_DatastoreBse'
    from_class    'CIM_StorageExtent'
    result_class  'MIQ_CimDatastore'
    role      'BaseStorageExtent'
    result_role   'Datastore'
  }

  # CIM_StorageExtent_TO_MIQ_CimHostSystem
  # MIQ_CimHostSystem_TO_CIM_StorageExtent
  add {
    assoc_class   'MIQ_HostBaseStorageExtent'
    from_class    'CIM_StorageExtent'
    result_class  'MIQ_CimHostSystem'
    role      'BaseStorageExtent'
    result_role   'Host'
  }

  # CIM_StorageExtent_TO_MIQ_CimVirtualMachine
  # MIQ_CimVirtualMachine_TO_CIM_StorageExtent
  add {
    assoc_class   'MIQ_VirtualMachineBaseStorageExtent'
    from_class    'CIM_StorageExtent'
    result_class  'MIQ_CimVirtualMachine'
    role      'BaseStorageExtent'
    result_role   'VirtualMachine'
  }

  # CIM_StorageVolume_TO_CIM_StorageExtent
  # CIM_StorageExtent_TO_CIM_StorageVolume
  add {
    assoc_class   'MIQ_StorageVolumeBaseStorageExtent'
    from_class    'CIM_StorageVolume'
    result_class  'CIM_StorageExtent'
    role      'StorageVolume'
    result_role   'BaseStorageExtent'
  }

  # CIM_StorageVolume_TO_MIQ_CimVirtualDisk
  # MIQ_CimVirtualDisk_TO_CIM_StorageVolume
  add {
    assoc_class   'MIQ_StorageVolumeVirtualDisk'
    from_class    'CIM_StorageVolume'
    result_class  'MIQ_CimVirtualDisk'
    role      'StorageVolume'
    result_role   'VirtualDisk'
  }

  # CIM_StorageVolume_TO_MIQ_CimVirtualMachine
  # MIQ_CimVirtualMachine_TO_CIM_StorageVolume
  add {
    assoc_class   'MIQ_StorageVolumeVm'
    from_class    'CIM_StorageVolume'
    result_class  'MIQ_CimVirtualMachine'
    role      'StorageVolume'
    result_role   'VirtualMachine'
  }

  # CIM_StorageVolume_TO_MIQ_CimHostSystem
  # MIQ_CimHostSystem_TO_CIM_StorageVolume
  add {
    assoc_class   'MIQ_StorageVolumeHost'
    from_class    'CIM_StorageVolume'
    result_class  'MIQ_CimHostSystem'
    role      'StorageVolume'
    result_role   'Host'
  }

  # MIQ_CimDatastore_TO_SNIA_LocalFileSystem
  # SNIA_LocalFileSystem_TO_MIQ_CimDatastore
  add {
    assoc_class   'MIQ_DatastoreLocalFileSystem'
    from_class    'MIQ_CimDatastore'
    result_class  'SNIA_LocalFileSystem'
    role      'Datastore'
    result_role   'LocalFileSystem'
  }

  # MIQ_CimDatastore_TO_MIQ_CimVirtualMachine
  # MIQ_CimVirtualMachine_TO_MIQ_CimDatastore
  add {
    assoc_class   'MIQ_DatastoreVirtualMachine'
    from_class    'MIQ_CimDatastore'
    result_class  'MIQ_CimVirtualMachine'
    role      'Datastore'
    result_role   'VirtualMachine'
  }

  # MIQ_CimHostSystem_TO_SNIA_FileShare
  # SNIA_FileShare_TO_MIQ_CimHostSystem
  add {
    assoc_class   'MIQ_FileShareHost'
    from_class    'MIQ_CimHostSystem'
    result_class  'SNIA_FileShare'
    role      'Host'
    result_role   'FileShare'
  }

  # MIQ_CimHostSystem_TO_SNIA_LocalFileSystem
  # SNIA_LocalFileSystem_TO_MIQ_CimHostSystem
  add {
    assoc_class   'MIQ_HostFileSystem'
    from_class    'MIQ_CimHostSystem'
    result_class  'SNIA_LocalFileSystem'
    role      'Host'
    result_role   'FileSystem'
  }

  # MIQ_VirtualMachine_TO_MIQ_CimDatastore
  # MIQ_CimDatastore_TO_MIQ_VirtualMachine
  add {
    assoc_class   'MIQ_DatastoreVirtualMachine'
    from_class    'MIQ_VirtualMachine'
    result_class  'MIQ_CimDatastore'
    role      'VirtualMachine'
    result_role   'Datastore'
  }

  # MIQ_VirtualMachine_TO_SNIA_LocalFileSystem
  # SNIA_LocalFileSystem_TO_MIQ_VirtualMachine
  add {
    assoc_class   'MIQ_VirtualMachineFileSystem'
    from_class    'MIQ_VirtualMachine'
    result_class  'SNIA_LocalFileSystem'
    role      'VirtualMachine'
    result_role   'FileSystem'
  }

  # MIQ_VirtualMachine_TO_SNIA_FileShare
  # SNIA_FileShare_TO_MIQ_VirtualMachine
  add {
    assoc_class   'MIQ_FileShareVm'
    from_class    'MIQ_VirtualMachine'
    result_class  'SNIA_FileShare'
    role      'VirtualMachine'
    result_role   'FileShare'
  }

  # MIQ_VirtualMachine_TO_MIQ_CimStorageVolume
  # MIQ_CimStorageVolume_TO_MIQ_VirtualMachine
  add {
    assoc_class   'MIQ_StorageVolumeVm'
    from_class    'MIQ_VirtualMachine'
    result_class  'MIQ_CimStorageVolume'
    role      'VirtualMachine'
    result_role   'StorageVolume'
  }

  # MIQ_VirtualMachine_TO_CIM_ComputerSystem
  # CIM_ComputerSystem_TO_MIQ_VirtualMachine
  add {
    assoc_class   'MIQ_StorageSystemVm'
    from_class    'MIQ_VirtualMachine'
    result_class  'CIM_ComputerSystem'
    role      'VirtualMachine'
    result_role   'StorageSystem'
  }

  # MIQ_VirtualMachine_TO_CIM_LogicalDisk
  # CIM_LogicalDisk_TO_MIQ_VirtualMachine
  add {
    assoc_class   'MIQ_LogicalDiskVm'
    from_class    'MIQ_VirtualMachine'
    result_class  'CIM_LogicalDisk'
    role      'VirtualMachine'
    result_role   'LogicalDisk'
  }

  # MIQ_VirtualMachine_TO_CIM_StorageExtent
  # CIM_StorageExtent_TO_MIQ_VirtualMachine
  add {
    assoc_class   'MIQ_VirtualMachineBaseStorageExtent'
    from_class    'MIQ_VirtualMachine'
    result_class  'CIM_StorageExtent'
    role      'VirtualMachine'
    result_role   'BaseStorageExtent'
  }

  # SNIA_FileShare_TO_CIM_StorageExtent
  # CIM_StorageExtent_TO_SNIA_FileShare
  add {
    assoc_class   'MIQ_FileShareBaseStorageExtent'
    from_class    'SNIA_FileShare'
    result_class  'CIM_StorageExtent'
    role      'FileShare'
    result_role   'BaseStorageExtent'
  }

  # SNIA_FileShare_TO_MIQ_CimVirtualDisk
  # MIQ_CimVirtualDisk_TO_SNIA_FileShare
  add {
    assoc_class   'MIQ_FileShareVirtualDisk'
    from_class    'SNIA_FileShare'
    result_class  'MIQ_CimVirtualDisk'
    role      'FileShare'
    result_role   'VirtualDisk'
  }

  # SNIA_FileShare_TO_MIQ_CimVirtualMachine
  # MIQ_CimVirtualMachine_TO_SNIA_FileShare
  add {
    assoc_class   'MIQ_FileShareVm'
    from_class    'SNIA_FileShare'
    result_class  'MIQ_CimVirtualMachine'
    role      'FileShare'
    result_role   'VirtualMachine'
  }

} # CimAssociations.update
