module MiqAeMethodService
  class MiqAeServiceConfigurationProfile < MiqAeServiceModelBase
    expose :configuration_manager,       :association => true
    expose :configuration_tags,          :association => true
  end
end
