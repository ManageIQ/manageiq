module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_InfraManager_Host < MiqAeServiceHost
    expose :ironic_set_power_state
    expose :manageable
    expose :introspect
    expose :provide
    expose :destroy_ironic
  end
end
