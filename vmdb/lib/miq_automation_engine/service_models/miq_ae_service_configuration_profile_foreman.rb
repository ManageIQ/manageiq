module MiqAeMethodService
  class MiqAeServiceConfigurationProfileForeman < MiqAeServiceConfigurationProfile
    expose :parent,                            :association => true

    expose :direct_configuration_tags,            :association => true
    expose :direct_customization_script_ptable,   :association => true
    expose :direct_customization_script_medium,   :association => true
    expose :direct_operating_system_flavors,      :association => true

    expose :configuration_tags,                :association => true
  end
end
