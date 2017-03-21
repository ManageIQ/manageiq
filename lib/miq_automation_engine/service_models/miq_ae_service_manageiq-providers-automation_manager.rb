module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_AutomationManager < MiqAeServiceManageIQ_Providers_BaseManager
    expose :provider,               :association => true
    expose :configuration_profiles, :association => true
    expose :configured_systems,     :association => true
  end
end
