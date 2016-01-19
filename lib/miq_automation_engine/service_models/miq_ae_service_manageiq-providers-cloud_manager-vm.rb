module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_CloudManager_Vm < MiqAeServiceVm
    expose :availability_zone, :association => true
    expose :flavor,            :association => true
    expose :cloud_network,     :association => true
    expose :cloud_subnet,      :association => true
    expose :network_ports,     :association => true
    expose :network_routers,   :association => true
    expose :cloud_subnets,     :association => true
    expose :floating_ip,       :association => true
    expose :security_groups,   :association => true
    expose :key_pairs,         :association => true
  end
end
