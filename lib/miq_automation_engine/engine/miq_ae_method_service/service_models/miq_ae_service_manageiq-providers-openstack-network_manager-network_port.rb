module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_NetworkManager_NetworkPort < MiqAeServiceNetworkPort
    expose :network_routers, :association => true
    expose :public_networks, :association => true
  end
end
