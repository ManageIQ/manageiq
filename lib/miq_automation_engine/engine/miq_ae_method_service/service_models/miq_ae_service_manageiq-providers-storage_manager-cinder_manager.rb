module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_StorageManager_CinderManager < MiqAeServiceManageIQ_Providers_StorageManager
    expose :parent_manager,         :association => true
    expose :cloud_volumes,          :association => true
    expose :cloud_volume_snapshots, :association => true
  end
end
