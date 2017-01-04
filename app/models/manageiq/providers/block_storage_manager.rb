class ManageIQ::Providers::BlockStorageManager < ManageIQ::Providers::StorageManager
  has_many :cloud_volumes,          :foreign_key => :ems_id, :dependent => :destroy
  has_many :cloud_volume_snapshots, :foreign_key => :ems_id, :dependent => :destroy
  has_many :cloud_volume_backups,   :foreign_key => :ems_id, :dependent => :destroy

  supports :block_storage
end
