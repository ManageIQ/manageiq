module MiqAeMethodService
  class MiqAeServiceConfigurationProfileForeman < MiqAeServiceConfigurationProfile
    expose :parent,                            :association => true

    expose :raw_configuration_tags,            :association => true
    expose :raw_customization_script_ptable,   :association => true
    expose :raw_customization_script_medium,   :association => true
    expose :raw_operating_system_flavors,      :association => true

    expose :configuration_tags,                :association => true
    expose :customization_script_ptable,       :association => true
    expose :customization_script_medium,       :association => true
    expose :operating_system_flavors,          :association => true
  end
end
