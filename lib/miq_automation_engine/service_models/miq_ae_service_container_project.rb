module MiqAeMethodService
  class MiqAeServiceContainerProject < MiqAeServiceModelBase
    expose :ext_management_system,  :association => true
    expose :container_groups,       :association => true
  end
end
