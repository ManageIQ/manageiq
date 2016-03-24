module MiqAeMethodService
  class MiqAeServiceServiceTemplateAnsibleTower < MiqAeServiceServiceTemplate
    require_relative "mixins/miq_ae_service_service_ansible_tower_mixin"
    include MiqAeServiceServiceAnsibleTowerMixin
  end
end
