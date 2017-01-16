module MiqAeMethodService
  class MiqAeServiceContainerRoute < MiqAeServiceModelBase
    expose :ext_management_system,    :association => true
    expose :container_project,        :association => true
    expose :container_service,        :association => true
    expose :container_nodes,          :association => true
    expose :container_groups,         :association => true
    expose :labels,                   :association => true
    expose :is_tagged_with?
    expose :tags
  end
end
