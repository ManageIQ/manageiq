module MiqAeMethodService
  class MiqAeServiceCloudResourceQuota < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :cloud_tenant,          :association => true
  end
end
