module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_StorageManager < MiqAeServiceExtManagementSystem
    expose :parent_manager,         :association => true
    expose :cloud_volumes,          :association => true
    expose :cloud_volume_snapshots, :association => true
  end
end
