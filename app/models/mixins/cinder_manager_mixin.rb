module CinderManagerMixin
  extend ActiveSupport::Concern

  included do
    # TODO: how about many storage managers???
    # Should use has_many :storage_managers,
    has_one  :cinder_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::StorageManager::CinderManager",
             :autosave    => true

    delegate :cloud_volumes,
             :cloud_volume_snapshots,
             :cloud_volume_backups,
             :to        => :cinder_manager,
             :allow_nil => true

    private

    def ensure_cinder_managers
      ensure_cinder_manager
      cinder_manager.name = "#{name} Cinder Manager"
      propagate_child_attributes(cinder_manager)

      true
    end
  end
end
