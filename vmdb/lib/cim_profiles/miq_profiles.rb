require 'cim_profile_types'

CimProfiles.update {

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

  datastore_to_logical_disk {
    input_class 'MIQ_CimDatastore'
    add datastore_to_file_share << file_share_to_logical_disk
  }
  logical_disk_to_datastore datastore_to_logical_disk.reverse

  datastore_to_filesystem {
    input_class 'MIQ_CimDatastore'
    add datastore_to_logical_disk << logical_disk_to_filesystem
  }
  filesystem_to_datastore   datastore_to_filesystem.reverse

  file_share_to_virtual_disk  {
    input_class 'CIM_FileShare'
    add   file_share_to_datastore << datastore_to_virtual_disk
  }
  virtual_disk_file_share file_share_to_virtual_disk.reverse

  logical_disk_to_virtual_disk  {
    input_class 'CIM_LogicalDisk'
    add logical_disk_to_datastore << datastore_to_virtual_disk
  }
  virtual_disk_to_logical_disk  logical_disk_to_virtual_disk.reverse

  storage_volume_to_virtual_disk  {
    input_class 'CIM_StorageVolume'
    add   storage_volume_to_datastore << datastore_to_virtual_disk
  }
  virtual_disk_to_storage_volume  storage_volume_to_virtual_disk.reverse

  file_share_to_host  {
    input_class 'CIM_FileShare'
    add   file_share_to_datastore << datastore_to_host
  }
  host_to_file_share  file_share_to_host.reverse

  file_share_to_virtual_machine {
    input_class 'CIM_FileShare'
    add   file_share_to_virtual_disk << virtual_disk_to_virtual_machine
  }
  virtual_machine_file_share  file_share_to_virtual_machine.reverse

  storage_volume_to_virtual_machine {
    input_class 'CIM_StorageVolume'
    add   storage_volume_to_virtual_disk << virtual_disk_to_virtual_machine
  }
  virtual_machine_to_storage_volume storage_volume_to_virtual_machine.reverse

  storage_volume_to_host  {
    input_class 'CIM_StorageVolume'
    add   storage_volume_to_datastore << datastore_to_host
  }
  host_to_storage_volume  storage_volume_to_host.reverse

  logical_disk_to_virtual_machine {
    input_class 'CIM_LogicalDisk'
    add logical_disk_to_virtual_disk << virtual_disk_to_virtual_machine
  }
  virtual_machine_to_logical_disk   logical_disk_to_virtual_machine.reverse

  logical_disk_to_host  {
    input_class 'CIM_LogicalDisk'
    add logical_disk_to_datastore << datastore_to_host
  }
  host_to_logical_disk  logical_disk_to_host.reverse

  datastore_to_virtual_machine  {
    input_class 'MIQ_CimDatastore'
    add   datastore_to_virtual_disk << virtual_disk_to_virtual_machine
  }
  virtual_machine_to_datastore  datastore_to_virtual_machine.reverse

  storage_system_to_datastore {
    input_class 'CIM_ComputerSystem'
    add   storage_system_to_file_shares   << file_share_to_datastore
    add   storage_system_to_storage_volume  << storage_volume_to_datastore
  }

  datastore_to_storage_system {
    input_class 'MIQ_CimDatastore'
    add   datastore_to_file_share   << file_share_to_storage_system
    add   datastore_to_storage_volume << storage_volume_to_storage_system
  }

  datastore_to_base_storage_extent {
    input_class 'MIQ_CimDatastore'
    add   datastore_to_logical_disk << storage_extent_to_base_storage_extent
    add   datastore_to_storage_volume << storage_extent_to_base_storage_extent
  }

  virtual_machine_to_filesystem {
    input_class 'MIQ_CimVirtualMachine'
    add   virtual_machine_to_datastore << datastore_to_filesystem
  }

  virtual_machine_to_base_storage_extent {
    input_class 'MIQ_CimVirtualMachine'
    add   virtual_machine_to_datastore << datastore_to_base_storage_extent
  }

  host_to_base_storage_extent {
    input_class 'MIQ_CimHostSystem'
    add   host_to_datastore << datastore_to_base_storage_extent
  }

  host_to_filesystem  {
    input_class 'MIQ_CimHostSystem'
    add   host_to_datastore << datastore_to_filesystem
  }

  storage_system_to_virtual_machine {
    input_class 'CIM_ComputerSystem'
    add   storage_system_to_datastore
    node_with_tag(:storage_system_to_file_shares).append_next!(datastore_to_virtual_machine)
    node_with_tag(:storage_system_to_storage_volume).append_next!(datastore_to_virtual_machine)
  }

  storage_system_to_host  {
    input_class 'CIM_ComputerSystem'
    add   storage_system_to_datastore
    node_with_tag(:storage_system_to_file_shares).append_next!(datastore_to_host)
    node_with_tag(:storage_system_to_storage_volume).append_next!(datastore_to_host)
  }

} # CimProfiles.update
