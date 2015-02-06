module MiqAeMethodService
  class MiqAeServiceConfigurationProfileForeman < MiqAeServiceConfigurationProfile
    expose :customization_script_ptable,       :association => true
    expose :customization_script_medium,       :association => true
    expose :operating_system_flavors,          :association => true
  end
end
