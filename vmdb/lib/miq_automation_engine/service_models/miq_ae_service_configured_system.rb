module MiqAeMethodService
  class MiqAeServiceConfiguredSystem < MiqAeServiceModelBase
    expose :configuration_manager,   :association => true
    expose :configuration_profile,   :association => true
    expose :operating_system_flavor, :association => true
    expose :configuration_tags,      :association => true
  end
end
