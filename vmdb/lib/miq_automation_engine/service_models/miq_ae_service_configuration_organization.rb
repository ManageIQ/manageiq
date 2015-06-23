module MiqAeMethodService
  class MiqAeServiceConfigurationOrganization < MiqAeServiceModelBase
    expose :provisioning_manager,         :association => true
    expose :parent,                       :association => true
  end
end
