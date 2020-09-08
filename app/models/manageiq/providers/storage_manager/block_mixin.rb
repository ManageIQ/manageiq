module ManageIQ::Providers::StorageManager::BlockMixin
  extend ActiveSupport::Concern

  included do
    has_many :cloud_volumes,      :foreign_key => :ems_id,  :dependent => :destroy
    has_many :storage_systems,    :foreign_key => "ems_id", :dependent => :destroy, :inverse_of => :ext_management_system
    has_many :storage_resources,  :foreign_key => "ems_id", :dependent => :destroy, :inverse_of => :ext_management_system
    has_many :storage_system_types, :foreign_key => :ems_id, :dependent => :destroy, :inverse_of => :ext_management_system
    has_many :storage_services, :foreign_key => "ems_id", :dependent => :destroy, :inverse_of => :ext_management_system

    # TODO: [liran] - move this into cinder-storage (this is not general block mixin props)
    has_many :cloud_volume_snapshots, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_backups,   :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_types,     :foreign_key => :ems_id, :dependent => :destroy

    supports :block_storage
  end
end
