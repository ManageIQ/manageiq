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
      ensure_swift_manager
      swift_manager.name = "#{name} Swift Manager"
      propagate_child_attributes(swift_manager)

      true
    end
  end
end
