module SwiftManagerMixin
  extend ActiveSupport::Concern

  included do
    has_one  :swift_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::StorageManager::SwiftManager",
             :autosave    => true

    delegate :cloud_object_store_containers,
             :cloud_object_store_objects,
             :to        => :swift_manager,
             :allow_nil => true

    private

    def ensure_swift_managers
      created = ensure_swift_manager
      swift_manager.name            = "#{name} Swift Manager"
      swift_manager.zone_id         = zone_id
      swift_manager.provider_region = provider_region

      return true unless created

      begin
        swift_manager.save
        swift_manager.reload
        _log.debug("swift_manager.id = #{swift_manager.id}")

        CloudObjectStoreContainer.where(:ems_id => id).update(:ems_id => swift_manager.id)
        CloudObjectStoreObject.where(:ems_id => id).update(:ems_id => swift_manager.id)
      rescue ActiveRecord::RecordNotFound
        # In case parent manager is not valid, let its validation fail.
      end
      true
    end
  end
end
