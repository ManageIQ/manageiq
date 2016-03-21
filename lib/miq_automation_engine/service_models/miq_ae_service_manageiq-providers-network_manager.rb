module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_NetworkManager < MiqAeServiceExtManagementSystem
    expose :parent_manager,         :association => true
    expose :cloud_networks,         :association => true
    expose :cloud_subnets,          :association => true
    expose :public_networks,        :association => true
    expose :private_networks,       :association => true
    expose :floating_ips,           :association => true
    expose :network_routers,        :association => true
    expose :network_ports,          :association => true
    expose :security_groups,        :association => true
  end
end
