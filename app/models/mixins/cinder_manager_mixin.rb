module CinderManagerMixin
  extend ActiveSupport::Concern

  included do
    # TODO: how about many storage managers???
    # Should use has_many :storage_managers,
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

    private

    def ensure_cinder_managers
      created = ensure_cinder_manager
      cinder_manager.name            = "#{name} Cinder Manager"
      cinder_manager.zone_id         = zone_id
      cinder_manager.provider_region = provider_region

      return true unless created

      begin
        cinder_manager.save
        cinder_manager.reload
        _log.debug "cinder_manager.id = #{cinder_manager.id}"

        CloudVolume.where(:ems_id => id).update(:ems_id => cinder_manager.id)
        CloudVolumeBackup.where(:ems_id => id).update(:ems_id => cinder_manager.id)
        CloudVolumeSnapshot.where(:ems_id => id).update(:ems_id => cinder_manager.id)
      rescue ActiveRecord::RecordNotFound
        # In case parent manager is not valid, let its validation fail.
      end
      true
    end
  end
end
