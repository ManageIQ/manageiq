module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Foreman_Provider < MiqAeServiceProvider
    expose :configuration_manager, :association => true
    expose :provisioning_manager,  :association => true
  end
end
