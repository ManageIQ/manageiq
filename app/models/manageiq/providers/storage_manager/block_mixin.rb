module ManageIQ::Providers::StorageManager::BlockMixin
  extend ActiveSupport::Concern

  included do
    has_many :cloud_volumes, :foreign_key => :ems_id, :dependent => :destroy
    has_many :physical_storages, :foreign_key => "ems_id", :dependent => :destroy,
             :inverse_of => :ext_management_system
    has_many :storage_resources, :foreign_key => "ems_id", :dependent => :destroy,
             :inverse_of => :ext_management_system
    has_many :physical_storage_families, :foreign_key => :ems_id, :dependent => :destroy,
             :inverse_of => :ext_management_system
    has_many :storage_services, :foreign_key => "ems_id", :dependent => :destroy,
             :inverse_of => :ext_management_system
    has_many :service_resource_attachments, :foreign_key => "ems_id",
             :dependent => :destroy, :inverse_of => :ext_management_system

    has_many :cloud_volume_snapshots, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_backups,   :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_types,     :foreign_key => :ems_id, :dependent => :destroy

    supports :block_storage
  end
end
