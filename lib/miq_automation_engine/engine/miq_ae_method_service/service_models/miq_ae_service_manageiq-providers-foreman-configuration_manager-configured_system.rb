module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Foreman_ConfigurationManager_ConfiguredSystem < MiqAeServiceConfiguredSystem
    expose :configuration_profile,           :association => true
    expose :configuration_tags,              :association => true

    expose :direct_customization_script_media,  :association => true
    expose :direct_customization_script_ptable, :association => true
    expose :direct_configuration_tags,          :association => true
  end
end
