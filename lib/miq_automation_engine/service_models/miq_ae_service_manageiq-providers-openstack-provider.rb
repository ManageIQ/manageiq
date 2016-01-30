module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_Provider < MiqAeServiceProvider
    expose :infra_ems, :association => true
    expose :cloud_ems, :association => true
  end
end
