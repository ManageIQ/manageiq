module MiqAeMethodService
  class MiqAeServiceConfigurationScript < MiqAeServiceModelBase
    expose :inventory_root_group, :association => true
    expose :manager,              :association => true
  end
end
