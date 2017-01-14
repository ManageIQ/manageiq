module MiqAeMethodService
  class MiqAeServiceConfigurationTag < MiqAeServiceModelBase
    expose :manager,                :association => true
    expose :configured_systems,     :association => true
    expose :configuration_profiles, :association => true
  end
end
