
module MiqAeMethodService
  class MiqAeServiceContainerBuildPod < MiqAeServiceModelBase
    expose :ext_management_system,  :association => true
    expose :container_build,        :association => true
    expose :labels,                 :association => true
    expose :container_group,        :association => true
    expose :is_tagged_with?
    expose :tags
  end
end
