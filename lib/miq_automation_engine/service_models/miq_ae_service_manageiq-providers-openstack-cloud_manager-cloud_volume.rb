module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_CloudManager_CloudVolume < MiqAeServiceCloudVolume
    def backup_create(backup_name = "", incremental = false, options = {})
      backup_options = {
        :name        => backup_name,
        :incremental => incremental
      }
      sync_or_async_ems_operation(options[:sync], "backup_create", [backup_options])
    end

    def backup_restore(backup_id, options = {})
      sync_or_async_ems_operation(options[:sync], "backup_restore", [backup_id])
    end
  end
end
