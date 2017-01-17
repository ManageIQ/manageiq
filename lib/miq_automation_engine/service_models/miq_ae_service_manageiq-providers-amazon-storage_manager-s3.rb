module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Amazon_StorageManager_S3 < MiqAeServiceManageIQ_Providers_StorageManager
    expose :parent_manager,                :association => true
    expose :cloud_object_store_containers, :association => true
    expose :cloud_object_store_objects,    :association => true
  end
end
