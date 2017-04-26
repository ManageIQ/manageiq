module MiqAeMethodService
  class MiqAeServiceServiceAnsibleTower < MiqAeServiceService
    require_relative "mixins/miq_ae_service_service_ansible_tower_mixin"
    include MiqAeServiceServiceAnsibleTowerMixin

    expose :launch_job
    expose :job
    expose :job_options
    expose :job_options=

    CREATE_ATTRIBUTES = [:name, :description].freeze

    def self.create(options = {})
      attributes = options.symbolize_keys.slice(*CREATE_ATTRIBUTES)

      ar_method { MiqAeServiceModelBase.wrap_results(ServiceAnsibleTower.create!(attributes)) }
    end
  end
end
