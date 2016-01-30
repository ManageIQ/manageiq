module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_CloudManager < MiqAeServiceExtManagementSystem
    expose :availability_zones,     :association => true
    expose :cloud_networks,         :association => true
    expose :public_networks,        :association => true
    expose :private_networks,       :association => true
    expose :cloud_tenants,          :association => true
    expose :flavors,                :association => true
    expose :floating_ips,           :association => true
    expose :key_pairs,              :association => true
    expose :security_groups,        :association => true
    expose :cloud_resource_quotas,  :association => true
    expose :orchestration_stacks,   :association => true
  end
end
