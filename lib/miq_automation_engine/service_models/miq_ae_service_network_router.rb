module MiqAeMethodService
  class MiqAeServiceNetworkRouter < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :cloud_tenant,          :association => true
    expose :public_network,        :association => true
    expose :vms,                   :association => true
    expose :floating_ips,          :association => true
    expose :network_ports,         :association => true
    expose :vms,                   :association => true
    expose :private_networks,      :association => true

    expose :raw_update_network_router
    expose :raw_delete_network_router
  end
end
