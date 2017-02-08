module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_NetworkManager_CloudNetwork < MiqAeServiceCloudNetwork
    expose :ip_address_left_count
    expose :ip_address_left_count_live
    expose :ip_address_total_count
    expose :ip_address_used_count
    expose :ip_address_used_count_live
    expose :ip_address_utilization
    expose :ip_address_utilization_live
  end
end
