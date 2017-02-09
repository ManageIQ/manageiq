module MiqAeMethodService
  class MiqAeServiceNetworkPort < MiqAeServiceModelBase
    expose :cloud_tenant,          :association => true
    expose :cloud_subnets,         :association => true
    expose :device,                :association => true
    expose :ext_management_system, :association => true
    expose :public_network,        :association => true
    expose :public_networks,       :association => true
  end
end
