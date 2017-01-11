module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_NetworkManager_CloudNetwork_Public < MiqAeServiceManageIQ_Providers_Openstack_NetworkManager_CloudNetwork
    expose :private_networks, :association => true
  end
end
