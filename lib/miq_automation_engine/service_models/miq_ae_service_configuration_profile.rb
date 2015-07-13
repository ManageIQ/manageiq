module MiqAeMethodService
  class MiqAeServiceConfigurationProfile < MiqAeServiceModelBase
    expose :manager,                      :association => true
    expose :parent,                       :association => true

    expose :configured_systems,           :association => true
    expose :customization_script_ptable,  :association => true
    expose :customization_script_medium,  :association => true
    expose :operating_system_flavors,     :association => true
  end
end
