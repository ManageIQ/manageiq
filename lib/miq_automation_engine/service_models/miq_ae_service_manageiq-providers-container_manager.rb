module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_ContainerManager < MiqAeServiceManageIQ_Providers_BaseManager
    expose :container_image_registries, :association => true
    expose :container_projects,         :association => true
  end
end
