require 'cim_profile_types'

CimProfiles.update {

  storage_system_to_file_shares   CimAssociations.CIM_ComputerSystem_TO_CIM_FileShare
  file_share_to_storage_system    storage_system_to_file_shares.reverse

  storage_system_to_storage_volume  CimAssociations.CIM_ComputerSystem_TO_CIM_StorageVolume
  storage_volume_to_storage_system  storage_system_to_storage_volume.reverse

  storage_system_to_logical_disk    CimAssociations.CIM_ComputerSystem_TO_CIM_LogicalDisk
  logical_disk_to_storage_system    storage_system_to_logical_disk.reverse

  logical_disk_to_filesystem      CimAssociations.CIM_StorageExtent_TO_SNIA_LocalFileSystem
  filesystem_to_logical_disk      logical_disk_to_filesystem.reverse

  file_share_to_filesystem      CimAssociations.CIM_FileShare_TO_SNIA_LocalFileSystem
  filesystem_to_file_share      file_share_to_filesystem.reverse

  filesystem_to_storage_extent    CimAssociations.SNIA_LocalFileSystem_TO_CIM_StorageExtent
  storage_extent_to_filesystem    filesystem_to_storage_extent.reverse

  file_share_to_ip_protocol_end_point {
    input_class 'CIM_FileShare'
    node  {
      tag       :file_share_to_ip_protocol_end_point
      add_flags   :pruneUnless => 'Protocol'
      add_association :CIM_FileShare_TO_CIM_ProtocolEndpoint
      add_next! {
        add_association :CIM_ProtocolEndpoint_TO_CIM_NetworkPort
        add_next! {
          add_association :CIM_NetworkPort_TO_CIM_IPProtocolEndpoint
        }
      }
    }
  }

  storage_extent_to_base_storage_extent {
    input_class 'CIM_StorageExtent'
    node  {
      tag       :storage_extent_to_base_storage_extent
      add_flags   :recurse => true
      add_association :CIM_StorageExtent_TO_CIM_StorageExtent_down
    }
  }
  base_storage_extent_to_top_storage_extent storage_extent_to_base_storage_extent.reverse

  storage_extent_to_storage_setting {
    input_class 'CIM_StorageExtent'
    node  {
      tag       :storage_extent_to_storage_setting
      add_flags   :pruneUnless => 'settings'
      add_association :CIM_StorageExtent_TO_CIM_StorageSetting
    }
  }

  storage_system_to_filesystem  {
    input_class 'CIM_ComputerSystem'
    add   storage_system_to_logical_disk << logical_disk_to_filesystem
  }
  filesystem_to_storage_system  storage_system_to_filesystem.reverse

  storage_system_to_base_storage_extent {
    input_class 'CIM_ComputerSystem'
    node  {
      tag       :storage_extent_to_storage_setting
      add_association :CIM_ComputerSystem_TO_CIM_StorageVolume
      add_association :CIM_ComputerSystem_TO_CIM_LogicalDisk
      add_next!   storage_extent_to_base_storage_extent
    }
  }

  file_share_to_logical_disk  {
    input_class 'CIM_FileShare'
    add file_share_to_filesystem << filesystem_to_storage_extent
  }
  logical_disk_to_file_share      file_share_to_logical_disk.reverse

  file_share_to_base_storage_extent {
    input_class 'CIM_FileShare'
    add file_share_to_logical_disk << storage_extent_to_base_storage_extent
  }

  storage_system  {
    input_class 'CIM_ComputerSystem'
    node  {
      tag       :storage_system_to_file_shares
      add_association :CIM_ComputerSystem_TO_CIM_FileShare
      add_next!   file_share_to_base_storage_extent
    }
    add   storage_system_to_storage_volume << storage_extent_to_base_storage_extent
    node_with_tag(:storage_system_to_file_shares).add_next!(file_share_to_ip_protocol_end_point)
    node_with_tag(:storage_system_to_file_shares).node_with_tag(:storage_extent_to_base_storage_extent).add_next!(
            storage_extent_to_storage_setting
    )
    node_with_tag(:storage_system_to_storage_volume).node_with_tag(:storage_extent_to_base_storage_extent).add_next!(
            storage_extent_to_storage_setting
    )
  }

} # CimProfiles.update
