module MiqAeMethodService
  class MiqAeServiceCloudObjectStoreContainer < MiqAeServiceModelBase
    expose :ext_management_system,      :association => true
    expose :cloud_tenant,               :association => true
    expose :cloud_object_store_objects, :association => true
  end
end
