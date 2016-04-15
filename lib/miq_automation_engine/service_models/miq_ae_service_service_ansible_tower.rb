module MiqAeMethodService
  class MiqAeServiceServiceAnsibleTower < MiqAeServiceService
    require_relative "mixins/miq_ae_service_service_ansible_tower_mixin"
    include MiqAeServiceServiceAnsibleTowerMixin

    expose :launch_job
    expose :job
    expose :job_options
    expose :job_options=
  end
end
