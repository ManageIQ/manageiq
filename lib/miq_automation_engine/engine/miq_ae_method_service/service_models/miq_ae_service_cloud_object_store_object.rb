module MiqAeMethodService
  class MiqAeServiceCloudObjectStoreObject < MiqAeServiceModelBase
    expose :ext_management_system,        :association => true
    expose :cloud_tenant,                 :association => true
    expose :cloud_object_store_container, :association => true
  end
end
