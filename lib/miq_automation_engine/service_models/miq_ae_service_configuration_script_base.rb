module MiqAeMethodService
  class MiqAeServiceConfigurationScriptBase < MiqAeServiceModelBase
    expose :inventory_root_group, :association => true
    expose :manager,              :association => true
  end
end
