module MiqAeMethodService
  class MiqAeServiceTenant < MiqAeServiceModelBase
    expose :tenant_quotas, :association => true
    expose :miq_requests,  :association => true
    expose :miq_request_tasks, :association => true
    expose :services, :association => true
    expose :providers, :association => true
    expose :ext_management_systems, :association => true
    expose :vm_or_templates, :association => true
    expose :vms, :association => true
    expose :miq_templates, :association => true
    expose :service_templates, :association => true
    expose :miq_groups, :association => true
    expose :users, :association => true
    expose :ae_domains, :association => true
  end
end
