module MiqAeMethodService
  class MiqAeServiceOrchestrationTemplateHot < MiqAeServiceOrchestrationTemplate
    CREATE_ATTRIBUTES = [:name, :description, :content, :draft, :orderable].freeze

    def self.create(options = {})
      attributes = options.symbolize_keys.slice(*CREATE_ATTRIBUTES)

      ar_method { MiqAeServiceOrchestrationTemplateHot.wrap_results(OrchestrationTemplateHot.create!(attributes)) }
    end
  end
end
