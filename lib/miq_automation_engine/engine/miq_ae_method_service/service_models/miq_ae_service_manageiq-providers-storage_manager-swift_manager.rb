module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_StorageManager_SwiftManager < MiqAeServiceManageIQ_Providers_StorageManager
    expose :parent_manager,                :association => true
    expose :cloud_object_store_containers, :association => true
    expose :cloud_object_store_objects,    :association => true
  end
end
