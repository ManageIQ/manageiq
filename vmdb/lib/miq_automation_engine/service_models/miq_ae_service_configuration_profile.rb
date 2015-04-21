module MiqAeMethodService
  class MiqAeServiceConfigurationProfile < MiqAeServiceModelBase
    expose :configuration_manager,        :association => true
    expose :parent,                       :association => true
  end
end
