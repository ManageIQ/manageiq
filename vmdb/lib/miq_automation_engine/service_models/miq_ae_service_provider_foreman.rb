module MiqAeMethodService
  class MiqAeServiceProviderForeman < MiqAeServiceProvider
    expose :configuration_manager, :association => true
    expose :provisioning_manager,  :association => true
  end
end
