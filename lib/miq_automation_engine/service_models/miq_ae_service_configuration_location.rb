module MiqAeMethodService
  class MiqAeServiceConfigurationLocation < MiqAeServiceModelBase
    expose :provisioning_manager,         :association => true
    expose :parent,                       :association => true
  end
end
