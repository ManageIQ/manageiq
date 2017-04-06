module MiqAeMethodService
  class MiqAeServiceOrchestrationTemplateVnfd < MiqAeServiceOrchestrationTemplate
    CREATE_ATTRIBUTES = [:name, :description, :content, :draft, :orderable, :ems_id].freeze

    def self.create(options = {})
      attributes = options.symbolize_keys.slice(*CREATE_ATTRIBUTES)

      ar_method { MiqAeServiceOrchestrationTemplateVnfd.wrap_results(OrchestrationTemplateVnfd.create!(attributes)) }
    end
  end
end
