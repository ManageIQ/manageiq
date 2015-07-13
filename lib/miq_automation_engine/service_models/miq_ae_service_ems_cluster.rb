module MiqAeMethodService
  class MiqAeServiceEmsCluster < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :hosts,                 :association => true
    expose :storages,              :association => true
    expose :default_resource_pool, :association => true
    expose :resource_pools,        :association => true
    expose :all_resource_pools,    :association => true
    expose :vms,                   :association => true
    expose :all_vms,               :association => true
    expose :parent_folder,         :association => true
    expose :ems_events,            :association => true

    def register_host(host)
      ar_method do
        MiqQueue.put(
          :class_name   => @object.class.name,
          :instance_id  => @object.id,
          :method_name  => "register_host",
          :zone         => @object.my_zone,
          :role         => "ems_operations",
          :args         => [host.id]
        )
        true
      end
    end

  end
end
