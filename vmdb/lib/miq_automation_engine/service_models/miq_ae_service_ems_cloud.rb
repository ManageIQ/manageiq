module MiqAeMethodService
  class MiqAeServiceEmsCloud < MiqAeServiceExtManagementSystem
    expose :availability_zones,    :association => true
    expose :cloud_networks,        :association => true
    expose :cloud_tenants,         :association => true
    expose :flavors,               :association => true
    expose :floating_ips,          :association => true
    expose :key_pairs,             :association => true
    expose :security_groups,       :association => true
    expose :cloud_resource_quotas, :association => true
  end
end
