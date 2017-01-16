
module MiqAeMethodService
  class MiqAeServiceContainerBuild < MiqAeServiceModelBase
    expose :ext_management_system,  :association => true
    expose :container_project,      :association => true
    expose :labels,                 :association => true
    expose :container_build_pods,   :association => true
    expose :is_tagged_with?
    expose :tags
  end
end
