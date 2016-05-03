module MiqAeMethodService
  class MiqAeServiceCloudNetwork < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :cloud_tenant,          :association => true
    expose :cloud_subnets,         :association => true
    expose :security_groups,       :association => true
    expose :vms,                   :association => true
    expose :floating_ips,          :association => true
    expose :network_ports,         :association => true
    expose :network_routers,       :association => true
  end
end
