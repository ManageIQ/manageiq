module MiqAeMethodService
  class MiqAeServiceEmsCloud < MiqAeServiceExtManagementSystem
    expose :availability_zones
    expose :cloud_networks
    expose :flavors
    expose :floating_ips
    expose :key_pairs
    expose :security_groups
  end
end
