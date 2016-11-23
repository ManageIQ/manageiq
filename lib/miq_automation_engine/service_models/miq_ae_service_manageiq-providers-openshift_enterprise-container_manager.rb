module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_OpenshiftEnterprise_ContainerManager < MiqAeServiceManageIQ_Providers_ContainerManager
    expose :container_image_registries, :association => true
  end
end
