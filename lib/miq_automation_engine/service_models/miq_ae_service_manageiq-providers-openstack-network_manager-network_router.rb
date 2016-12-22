module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_NetworkManager_NetworkRouter < MiqAeServiceNetworkRouter
    expose :update_network_router
    expose :delete_network_router
    expose :add_interface
    expose :remove_interface
  end
end
