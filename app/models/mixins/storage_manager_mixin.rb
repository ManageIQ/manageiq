module StorageManagerMixin
  extend ActiveSupport::Concern

  included do
    # TODO: how about many storage managers???
    # Should use has_many :storage_managers,
    has_one  :cinder_storage_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::StorageManager::CinderStorageManager",
             :autosave    => true,
             :dependent   => :destroy

    has_one  :swift_storage_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::StorageManager::SwiftStorageManager",
             :autosave    => true,
             :dependent   => :destroy

    delegate :cloud_volumes,
             :cloud_volume_snapshots,
             :cloud_volume_backups,
             :to        => :cinder_storage_manager,
             :allow_nil => true

    delegate :cloud_object_store_containers,
             :cloud_object_store_objects,
             :to        => :swift_storage_manager,
             :allow_nil => true

    private

    def ensure_storage_managers
      ensure_cinder_storage_manager
      cinder_storage_manager.name            = "#{name} Cinder Storage Manager"
      cinder_storage_manager.zone_id         = zone_id
      cinder_storage_manager.provider_region = provider_region

      ensure_swift_storage_manager
      swift_storage_manager.name            = "#{name} Swift Storage Manager"
      swift_storage_manager.zone_id         = zone_id
      swift_storage_manager.provider_region = provider_region
    end
  end
end
