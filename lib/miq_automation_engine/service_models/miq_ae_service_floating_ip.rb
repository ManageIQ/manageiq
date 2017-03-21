module MiqAeMethodService
  class MiqAeServiceFloatingIp < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :vm,                    :association => true
    expose :cloud_tenant,          :association => true
    expose :network_port,          :association => true
    expose :name
  end
end
