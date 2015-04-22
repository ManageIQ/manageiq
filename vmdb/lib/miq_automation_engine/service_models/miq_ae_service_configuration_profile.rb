module MiqAeMethodService
  class MiqAeServiceConfigurationProfile < MiqAeServiceModelBase
    expose :manager,                      :association => true
    expose :parent,                       :association => true
    expose :configured_systems,           :association => true
  end
end
