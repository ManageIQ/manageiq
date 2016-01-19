module MiqAeMethodService
  class MiqAeServiceNetworkPort < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :cloud_tenant,          :association => true
    expose :cloud_subnet,          :association => true
    expose :device,                :association => true
  end
end
