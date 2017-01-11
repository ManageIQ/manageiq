module MiqAeMethodService
  class MiqAeServiceCloudTenant < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :security_groups,       :association => true
    expose :cloud_networks,        :association => true
    expose :vms,                   :association => true
    expose :vms_and_templates,     :association => true
    expose :miq_templates,         :association => true
    expose :floating_ips,          :association => true
    expose :cloud_resource_quotas, :association => true

    expose :raw_update_cloud_tenant
    expose :raw_delete_cloud_tenant
  end
end
