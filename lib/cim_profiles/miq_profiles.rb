require 'cim_profile_types'

CimProfiles.update do
  datastore_to_storage_volume   CimAssociations.MIQ_CimDatastore_TO_CIM_StorageVolume
  storage_volume_to_datastore   datastore_to_storage_volume.reverse

  datastore_to_file_share     CimAssociations.MIQ_CimDatastore_TO_CIM_FileShare
  file_share_to_datastore     datastore_to_file_share.reverse

  datastore_to_virtual_disk   CimAssociations.MIQ_CimDatastore_TO_MIQ_CimVirtualDisk
  virtual_disk_to_datastore   datastore_to_virtual_disk.reverse

  datastore_to_host       CimAssociations.MIQ_CimDatastore_TO_MIQ_CimHostSystem
  host_to_datastore       datastore_to_host.reverse

  virtual_disk_to_virtual_machine CimAssociations.MIQ_CimVirtualDisk_TO_MIQ_CimVirtualMachine
  virtual_machine_to_virtual_disk virtual_disk_to_virtual_machine.reverse

  datastore_to_logical_disk do
    input_class 'MIQ_CimDatastore'
    add datastore_to_file_share << file_share_to_logical_disk
  end
  logical_disk_to_datastore datastore_to_logical_disk.reverse

  datastore_to_filesystem do
    input_class 'MIQ_CimDatastore'
    add datastore_to_logical_disk << logical_disk_to_filesystem
  end
  filesystem_to_datastore   datastore_to_filesystem.reverse

  file_share_to_virtual_disk  do
    input_class 'CIM_FileShare'
    add   file_share_to_datastore << datastore_to_virtual_disk
  end
  virtual_disk_file_share file_share_to_virtual_disk.reverse

  logical_disk_to_virtual_disk  do
    input_class 'CIM_LogicalDisk'
    add logical_disk_to_datastore << datastore_to_virtual_disk
  end
  virtual_disk_to_logical_disk  logical_disk_to_virtual_disk.reverse

  storage_volume_to_virtual_disk  do
    input_class 'CIM_StorageVolume'
    add   storage_volume_to_datastore << datastore_to_virtual_disk
  end
  virtual_disk_to_storage_volume  storage_volume_to_virtual_disk.reverse

  file_share_to_host  do
    input_class 'CIM_FileShare'
    add   file_share_to_datastore << datastore_to_host
  end
  host_to_file_share  file_share_to_host.reverse

  file_share_to_virtual_machine do
    input_class 'CIM_FileShare'
    add   file_share_to_virtual_disk << virtual_disk_to_virtual_machine
  end
  virtual_machine_file_share  file_share_to_virtual_machine.reverse

  storage_volume_to_virtual_machine do
    input_class 'CIM_StorageVolume'
    add   storage_volume_to_virtual_disk << virtual_disk_to_virtual_machine
  end
  virtual_machine_to_storage_volume storage_volume_to_virtual_machine.reverse

  storage_volume_to_host  do
    input_class 'CIM_StorageVolume'
    add   storage_volume_to_datastore << datastore_to_host
  end
  host_to_storage_volume  storage_volume_to_host.reverse

  logical_disk_to_virtual_machine do
    input_class 'CIM_LogicalDisk'
    add logical_disk_to_virtual_disk << virtual_disk_to_virtual_machine
  end
  virtual_machine_to_logical_disk   logical_disk_to_virtual_machine.reverse

  logical_disk_to_host  do
    input_class 'CIM_LogicalDisk'
    add logical_disk_to_datastore << datastore_to_host
  end
  host_to_logical_disk  logical_disk_to_host.reverse

  datastore_to_virtual_machine  do
    input_class 'MIQ_CimDatastore'
    add   datastore_to_virtual_disk << virtual_disk_to_virtual_machine
  end
  virtual_machine_to_datastore  datastore_to_virtual_machine.reverse

  storage_system_to_datastore do
    input_class 'CIM_ComputerSystem'
    add   storage_system_to_file_shares << file_share_to_datastore
    add   storage_system_to_storage_volume << storage_volume_to_datastore
  end

  datastore_to_storage_system do
    input_class 'MIQ_CimDatastore'
    add   datastore_to_file_share << file_share_to_storage_system
    add   datastore_to_storage_volume << storage_volume_to_storage_system
  end

  datastore_to_base_storage_extent do
    input_class 'MIQ_CimDatastore'
    add   datastore_to_logical_disk << storage_extent_to_base_storage_extent
    add   datastore_to_storage_volume << storage_extent_to_base_storage_extent
  end

  virtual_machine_to_filesystem do
    input_class 'MIQ_CimVirtualMachine'
    add   virtual_machine_to_datastore << datastore_to_filesystem
  end

  virtual_machine_to_base_storage_extent do
    input_class 'MIQ_CimVirtualMachine'
    add   virtual_machine_to_datastore << datastore_to_base_storage_extent
  end

  host_to_base_storage_extent do
    input_class 'MIQ_CimHostSystem'
    add   host_to_datastore << datastore_to_base_storage_extent
  end

  host_to_filesystem  do
    input_class 'MIQ_CimHostSystem'
    add   host_to_datastore << datastore_to_filesystem
  end

  storage_system_to_virtual_machine do
    input_class 'CIM_ComputerSystem'
    add   storage_system_to_datastore
    node_with_tag(:storage_system_to_file_shares).append_next!(datastore_to_virtual_machine)
    node_with_tag(:storage_system_to_storage_volume).append_next!(datastore_to_virtual_machine)
  end

  storage_system_to_host  do
    input_class 'CIM_ComputerSystem'
    add   storage_system_to_datastore
    node_with_tag(:storage_system_to_file_shares).append_next!(datastore_to_host)
    node_with_tag(:storage_system_to_storage_volume).append_next!(datastore_to_host)
  end
end # CimProfiles.update
