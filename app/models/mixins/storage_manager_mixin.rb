module StorageManagerMixin
  extend ActiveSupport::Concern

  included do
    # TODO: how about many storage managers???
    has_one  :cinder_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::StorageManager::CinderManager",
             :autosave    => true,
             :dependent   => :destroy

    delegate :cloud_volumes,
             :cloud_volume_snapshots,
             :cloud_volume_backups,
             :to        => :cinder_manager,
             :allow_nil => true

    has_one  :swift_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::StorageManager::SwiftManager",
             :autosave    => true,
             :dependent   => :destroy

    delegate :cloud_object_store_containers,
             :cloud_object_store_objects,
             :to        => :swift_manager,
             :allow_nil => true

    private

    def ensure_storage_managers
      ensure_cinder_manager
      cinder_manager.name            = "#{name} Cinder Manager"
      cinder_manager.zone_id         = zone_id
      cinder_manager.provider_region = provider_region

      ensure_swift_manager
      swift_manager.name            = "#{name} Swift Manager"
      swift_manager.zone_id         = zone_id
      swift_manager.provider_region = provider_region
    end
  end
end
