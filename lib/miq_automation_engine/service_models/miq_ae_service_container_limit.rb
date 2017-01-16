module MiqAeMethodService
  class MiqAeServiceContainerLimit < MiqAeServiceModelBase
    expose :ext_management_system,  :association => true
    expose :container_project,      :association => true
    expose :container_limit_items,  :association => true
  end
end
