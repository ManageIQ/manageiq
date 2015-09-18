class CreateContainerVolumes < ActiveRecord::Migration
  def up
    create_table :container_volumes do |t|
      # prefixes are used to specify the volume source kind
      # the 'common' prefix is used when an entry is shard by some different kinds
      t.belongs_to :container_group, :type => :bigint
      t.string     :type
      t.string     :name
      t.string     :empty_dir_medium_type
      t.string     :gce_pd_name
      t.string     :git_repository
      t.string     :git_revision
      t.string     :nfs_server
      t.string     :iscsi_target_portal
      t.string     :iscsi_iqn
      t.integer    :iscsi_lun
      t.string     :glusterfs_endpoint_name
      t.string     :claim_name
      t.string     :rbd_ceph_monitors
      t.string     :rbd_image
      t.string     :rbd_pool
      t.string     :rbd_rados_user
      t.string     :rbd_keyring
      t.string     :common_path
      t.string     :common_fs_type
      t.string     :common_read_only
      t.string     :common_volume_id
      t.string     :common_partition
      t.string     :common_secret
    end
  end

  def down
    drop_table :container_volumes
  end
end
