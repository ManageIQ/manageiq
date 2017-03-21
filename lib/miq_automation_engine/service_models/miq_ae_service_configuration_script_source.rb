module MiqAeMethodService
  class MiqAeServiceConfigurationScriptSource < MiqAeServiceModelBase
    expose :manager,        :association => true
    expose :authentication, :association => true
    expose :configuration_script_payloads
  end
end
