module MiqAeMethodService
  class MiqAeServiceVmCloud < MiqAeServiceVm
    expose :availability_zone
    expose :flavor
    expose :cloud_network
    expose :cloud_subnet
    expose :floating_ip
    expose :security_groups
    expose :key_pairs
  end
end
