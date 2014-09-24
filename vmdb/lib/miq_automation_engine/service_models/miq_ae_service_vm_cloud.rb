module MiqAeMethodService
  class MiqAeServiceVmCloud < MiqAeServiceVm
    expose :availability_zone, :association => true
    expose :flavor,            :association => true
    expose :cloud_network,     :association => true
    expose :cloud_subnet,      :association => true
    expose :floating_ip,       :association => true
    expose :security_groups,   :association => true
    expose :key_pairs,         :association => true
  end
end
