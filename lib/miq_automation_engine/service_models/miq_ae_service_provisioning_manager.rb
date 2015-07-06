module MiqAeMethodService
  class MiqAeServiceProvisioningManager < MiqAeServiceModelBase
    expose :provider,                 :association => true
    expose :operating_system_flavors, :association => true
    expose :customization_scripts,    :association => true
  end
end
