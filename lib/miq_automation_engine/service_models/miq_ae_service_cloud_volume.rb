module MiqAeMethodService
  class MiqAeServiceCloudVolume < MiqAeServiceModelBase
    expose :ext_management_system,  :association => true
    expose :availability_zone,      :association => true
    expose :cloud_tenant,           :association => true
    expose :base_snapshot,          :association => true
    expose :cloud_volume_backups,   :association => true
    expose :cloud_volume_snapshots, :association => true
    expose :attachments,            :association => true

    def backup_create(backup_name, incremental = false, options = {})
      backup_options = {}
      backup_options[:name] = backup_name
      backup_options[:incremental] = incremental
      sync_or_async_ems_operation(options[:sync], "backup_create", [backup_options])
    end

    def backup_restore(backup_id, options = {})
      sync_or_async_ems_operation(options[:sync], "backup_restore", [backup_id])
    end
  end
end
