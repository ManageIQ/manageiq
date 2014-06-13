require 'cim_profile_types'

CimProfiles.update {

  ontap_raid_group_to_disk_extents  CimAssociations.ONTAP_RAIDGroupExtent_TO_ONTAP_DiskExtent
  ontap_plex_to_raid_group      CimAssociations.ONTAP_PlexExtent_TO_ONTAP_RAIDGroupExtent
  ontap_aggregate_to_plex       CimAssociations.ONTAP_ConcreteExtent_TO_ONTAP_PlexExtent
  ontap_flex_vol_to_aggregate     CimAssociations.ONTAP_FlexVolExtent_TO_ONTAP_ConcreteExtent
  ontap_file_share_to_flex_vol    CimAssociations.ONTAP_FileShare_TO_ONTAP_FlexVolExtent
  ontap_storage_volume_to_flex_vol  CimAssociations.ONTAP_StorageVolume_TO_ONTAP_FlexVolExtent

  ontap_flex_vol_to_disk_extents {
    input_class 'ONTAP_FlexVolExtent'
    add   ontap_flex_vol_to_aggregate <<
        ontap_aggregate_to_plex   <<
        ontap_plex_to_raid_group  <<
        ontap_raid_group_to_disk_extents
  }

  ontap_file_share_to_disk_extents {
    input_class 'ONTAP_FileShare'
    add ontap_file_share_to_flex_vol << ontap_flex_vol_to_disk_extents
  }

  ontap_storage_volume_to_disk_extents {
    input_class 'ONTAP_StorageVolume'
    add ontap_storage_volume_to_flex_vol << ontap_flex_vol_to_disk_extents
  }

  ontap_filer {
    input_class 'ONTAP_StorageSystem'
    node  {
      tag       :ontap_storage_system_to_file_shares
      add_association :ONTAP_StorageSystem_TO_ONTAP_FileShare
      add_next!   ontap_file_share_to_disk_extents
    }
    node  {
      tag       :ontap_storage_system_to_storage_volume
      add_association :ONTAP_StorageSystem_TO_ONTAP_StorageVolume
      add_next!   ontap_storage_volume_to_disk_extents
    }
  }

} # CimProfiles.update
