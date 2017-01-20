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

    expose :ip_address_total_count
    expose :ip_address_used_count
    expose :ip_address_left_count
    expose :ip_address_utilization
    expose :ip_address_used_count_live
    expose :ip_address_left_count_live
    expose :ip_address_utilization_live
  end
end
