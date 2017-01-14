module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_CloudManager_HostAggregate < MiqAeServiceHostAggregate
    expose :availability_zone
    expose :availability_zone_obj

    expose :update_aggregate
    expose :delete_aggregate
    expose :add_host
    expose :remove_host
  end
end
