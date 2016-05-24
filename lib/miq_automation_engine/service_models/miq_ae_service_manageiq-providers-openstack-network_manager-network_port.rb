module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_NetworkManager_NetworkPort < MiqAeServiceNetworkPort
    expose :cloud_subnets,   :association => true
    expose :network_routers, :association => true
    expose :public_networks, :association => true
  end
end
