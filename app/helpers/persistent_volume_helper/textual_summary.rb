module PersistentVolumeHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name creation_timestamp resource_version capacity access_modes reclaim_policy status_phase
       storage_medium_type gce_pd_resource git_repository git_revision nfs_server
       iscsi_target_portal iscsi_target_qualified_name iscsi_target_lun_number glusterfs_endpoint_name
       persistent_volume_claim_name rados_ceph_monitors rados_image_name rados_pool_name rados_user_name rados_keyring
       volume_path fs_type read_only volume_id partition secret_name)
  end

  def textual_group_relationships
    %i(parent)
  end

  def textual_group_smart_management
    items = %w(tags)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_name
    @record.name
  end

  def textual_creation_timestamp
    format_timezone(@record.creation_timestamp)
  end

  def textual_resource_version
    @record.resource_version
  end

  def textual_capacity
    @record.capacity
  end

  def textual_access_modes
    @record.access_modes
  end

  def textual_reclaim_policy
    @record.reclaim_policy
  end

  def textual_status_phase
    @record.status_phase
  end

  def textual_storage_medium_type
    type = @record.empty_dir_medium_type
    {:label => _("Storage Medium Type"),
     :value => type} if type
  end

  def textual_gce_pd_resource
    name = @record.gce_pd_name
    {:label => _("GCE PD Resource"),
     :value => name} if name
  end

  def textual_git_repository
    git_repository = @record.git_repository
    {:label => _("Git Repository"),
     :value => git_repository} if git_repository
  end

  def textual_git_revision
    git_revision = @record.git_revision
    {:label => _("Git Revision"),
     :value => git_revision} if git_revision
  end

  def textual_nfs_server
    nfs_server = @record.nfs_server
    {:label => _("NFS Server"),
     :value => nfs_server} if nfs_server
  end

  def textual_iscsi_target_portal
    target_portal = @record.iscsi_target_portal
    {:label => _("ISCSI Target Portal"),
     :value => target_portal} if target_portal
  end

  def textual_iscsi_target_qualified_name
    iscsi_iqn = @record.iscsi_iqn
    {:label => _("ISCSI Target Qualified Name"),
     :value => iscsi_iqn} if iscsi_iqn
  end

  def textual_iscsi_target_lun_number
    iscsi_lun = @record.iscsi_lun
    {:label => _("ISCSI Target Lun Number"),
     :value => iscsi_lun} if iscsi_lun
  end

  def textual_glusterfs_endpoint_name
    name = @record.glusterfs_endpoint_name
    {:label => _("Glusterfs Endpoint Name"),
     :value => name} if name
  end

  def textual_persistent_volume_claim_name
    claim_name = @record.claim_name
    {:label => _("Persistent Volume Claim Name"),
     :value => claim_name} if claim_name
  end

  def textual_rados_ceph_monitors
    ceph_monitors = @record.rbd_ceph_monitors
    {:label => _("Rados Ceph Monitors"),
     :value => ceph_monitors} unless ceph_monitors.empty?
  end

  def textual_rados_image_name
    rbd_image = @record.rbd_image
    {:label => _("Rados Image Name"),
     :value => rbd_image} if rbd_image
  end

  def textual_rados_pool_name
    rbd_pool = @record.rbd_pool
    {:label => _("Rados Pool Name"),
     :value => rbd_pool} if rbd_pool
  end

  def textual_rados_user_name
    rados_user = @record.rbd_rados_user
    {:label => _("Rados User Name"),
     :value => rados_user} if rados_user
  end

  def textual_rados_keyring
    rbd_keyring = @record.rbd_keyring
    {:label => _("Rados Keyring"),
     :value => rbd_keyring} if rbd_keyring
  end

  def textual_volume_path
    @record.common_path
  end

  def textual_fs_type
    fs_type = @record.common_fs_type
    {:label => _("FS Type"),
     :value => fs_type} if fs_type
  end

  def textual_read_only
    read_only = @record.common_read_only
    {:label => _("Read-Only"),
     :value => read_only} if read_only
  end

  def textual_volume_id
    volume_id = @record.common_volume_id
    {:label => _("Volume ID"),
     :value => volume_id} if volume_id
  end

  def textual_partition
    @record.common_partition
  end

  def textual_secret_name
    @record.common_secret
  end
end
