module MiqAeMethodService
  class MiqAeServiceVmCloud < MiqAeServiceVm
    expose :availability_zone, :association => true
    expose :flavor,            :association => true
    expose :cloud_network,     :association => true
    expose :cloud_networks,    :association => true
    expose :public_networks,   :association => true
    expose :private_networks,  :association => true
    expose :cloud_subnet,      :association => true
    expose :cloud_subnets,     :association => true
    expose :network_ports,     :association => true
    expose :network_routers,   :association => true
    expose :floating_ip,       :association => true
    expose :floating_ips,      :association => true
    expose :security_groups,   :association => true
    expose :key_pairs,         :association => true
    expose :associate_floating_ip
    expose :delete_floating_ips
    expose :destroy_if_failed
  end
end
