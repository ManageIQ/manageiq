module MiqAeMethodService
  class MiqAeServiceContainerImageRegistry < MiqAeServiceModelBase
    expose :ext_management_system,    :association => true
    expose :container_images,         :association => true
    expose :containers,               :association => true
    expose :container_services,       :association => true
    expose :container_groups,         :association => true
    expose :is_tagged_with?
    expose :tags
  end
end
