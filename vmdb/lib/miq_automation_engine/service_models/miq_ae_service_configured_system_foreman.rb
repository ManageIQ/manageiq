module MiqAeMethodService
  class MiqAeServiceConfiguredSystemForeman < MiqAeServiceConfiguredSystem
    expose :configuration_profile,           :association => true
    expose :configuration_location,          :association => true
    expose :operating_system_flavor,         :association => true
    expose :customization_script_media,      :association => true
    expose :customization_script_ptable,     :association => true
    expose :configuration_tags,              :association => true

    expose :raw_operating_system_flavor,     :association => true
    expose :raw_customization_script_media,  :association => true
    expose :raw_customization_script_ptable, :association => true
    expose :raw_configuration_tags,          :association => true
  end
end
