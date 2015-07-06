module MiqAeMethodService
  class MiqAeServiceCloudNetwork < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :cloud_tenant,          :association => true
    expose :cloud_subnets,         :association => true
    expose :security_groups,       :association => true
    expose :vms,                   :association => true
  end
end
