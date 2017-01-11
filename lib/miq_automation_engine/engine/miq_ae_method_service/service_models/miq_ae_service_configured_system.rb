module MiqAeMethodService
  class MiqAeServiceConfiguredSystem < MiqAeServiceModelBase
    expose :manager,                     :association => true
    expose :computer_system,             :association => true
    expose :configuration_profile,       :association => true
    expose :configuration_location,      :association => true
    expose :customization_script_media,  :association => true
    expose :customization_script_ptable, :association => true
    expose :operating_system_flavor,     :association => true
  end
end
