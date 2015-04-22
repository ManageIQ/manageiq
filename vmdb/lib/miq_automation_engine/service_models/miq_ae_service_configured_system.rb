module MiqAeMethodService
  class MiqAeServiceConfiguredSystem < MiqAeServiceModelBase
    expose :manager,                 :association => true
    expose :configuration_profile,   :association => true
    expose :computer_system,         :association => true
  end
end
