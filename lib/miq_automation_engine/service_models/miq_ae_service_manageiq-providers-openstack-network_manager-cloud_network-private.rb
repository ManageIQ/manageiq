module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_NetworkManager_CloudNetwork_Private < MiqAeServiceManageIQ_Providers_Openstack_NetworkManager_CloudNetwork
    expose :public_networks, :association => true
  end
end
