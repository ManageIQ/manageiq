module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_NetworkManager_NetworkPort < MiqAeServiceNetworkPort
    expose :cloud_network, :association => true
  end
end
