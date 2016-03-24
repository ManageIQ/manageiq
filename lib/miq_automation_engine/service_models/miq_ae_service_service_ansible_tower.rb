module MiqAeMethodService
  class MiqAeServiceServiceAnsibleTower < MiqAeServiceService
    require_relative "mixins/miq_ae_service_service_ansible_tower_mixin"
    include MiqAeServiceServiceAnsibleTowerMixin

    expose :launch_job
    expose :job
  end
end
