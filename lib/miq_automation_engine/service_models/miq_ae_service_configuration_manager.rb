module MiqAeMethodService
  class MiqAeServiceConfigurationManager < MiqAeServiceModelBase
    expose :provider,               :association => true
    expose :configuration_profiles, :association => true
    expose :configured_systems,     :association => true
  end
end
