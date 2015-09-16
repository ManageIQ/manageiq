module MiqAeMethodService
  class MiqAeServiceTenant < MiqAeServiceModelBase
    expose :tenant_quotas, :association => true
    expose :miq_requests,  :association => true
    expose :miq_request_tasks, :association => true
    expose :services, :association => true
  end
end
