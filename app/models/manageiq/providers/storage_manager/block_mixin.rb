module ManageIQ::Providers::StorageManager::BlockMixin
  extend ActiveSupport::Concern

  included do
    has_many :cloud_volumes,          :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_snapshots, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_backups,   :foreign_key => :ems_id, :dependent => :destroy

    supports :block_storage
  end
end
