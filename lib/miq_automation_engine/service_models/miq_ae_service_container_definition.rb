
module MiqAeMethodService
  class MiqAeServiceContainerDefinition < MiqAeServiceModelBase
    expose :container_group,        :association => true
    expose :ext_management_system,  :association => true
    expose :container_port_configs, :association => true
    expose :container_env_vars,     :association => true
    expose :container,              :association => true
    expose :security_context,       :association => true
    expose :container_image,        :association => true
  end
end
