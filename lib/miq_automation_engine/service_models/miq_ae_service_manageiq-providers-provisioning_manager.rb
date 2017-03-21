module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_ProvisioningManager < MiqAeServiceManageIQ_Providers_BaseManager
    expose :provider,                 :association => true
    expose :operating_system_flavors, :association => true
    expose :customization_scripts,    :association => true
  end
end
